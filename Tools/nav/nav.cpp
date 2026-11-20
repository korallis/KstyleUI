// Build one Recast navmesh from a triangle soup and query paths.
// Mesh file: uint32 vert count, xyz floats (WoW x, y, z-up), uint32 tri count, uint32 indices.
// Points file: name x y z, one place per line.
// Writes straight-path polylines in WoW coordinates.

#include "Recast.h"
#include "DetourNavMesh.h"
#include "DetourNavMeshBuilder.h"
#include "DetourNavMeshQuery.h"
#include "DetourCommon.h"

#include <algorithm>
#include <map>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <unordered_map>
#include <vector>

static bool read_u32(FILE* f, uint32_t* out) { return fread(out, 4, 1, f) == 1; }

static void wow_to_rc(float x, float y, float z, float* out) {
    out[0] = x;
    out[1] = z;
    out[2] = y;
}

static void rc_to_wow(const float* in, float* x, float* y, float* z) {
    *x = in[0];
    *z = in[1];
    *y = in[2];
}

int main(int argc, char** argv) {
    if (argc != 4) {
        fprintf(stderr, "usage: nav mesh.bin points.txt paths.txt\n");
        return 2;
    }
    FILE* mesh = fopen(argv[1], "rb");
    if (!mesh) {
        perror(argv[1]);
        return 1;
    }
    uint32_t nverts = 0, ntris = 0;
    if (!read_u32(mesh, &nverts)) return 1;
    std::vector<float> wow(nverts * 3);
    if (fread(wow.data(), 4, wow.size(), mesh) != wow.size()) return 1;
    if (!read_u32(mesh, &ntris)) return 1;
    std::vector<int> tris(ntris * 3);
    if (fread(tris.data(), 4, tris.size(), mesh) != tris.size()) return 1;
    fclose(mesh);

    std::vector<float> verts(nverts * 3);
    float bmin[3] = {1e9f, 1e9f, 1e9f};
    float bmax[3] = {-1e9f, -1e9f, -1e9f};
    for (uint32_t i = 0; i < nverts; i++) {
        wow_to_rc(wow[i * 3], wow[i * 3 + 1], wow[i * 3 + 2], &verts[i * 3]);
        for (int k = 0; k < 3; k++) {
            bmin[k] = std::min(bmin[k], verts[i * 3 + k]);
            bmax[k] = std::max(bmax[k], verts[i * 3 + k]);
        }
    }

    const float cs = 1.0f;
    const float ch = 0.2f;
    const float agentHeight = 2.0f;
    const float agentRadius = 0.4f;
    const float agentClimb = 1.4f;
    const float slope = 50.0f;

    const int tileSize = 256;
    float origin[3] = {floorf(bmin[0] / tileSize) * tileSize, bmin[1], floorf(bmin[2] / tileSize) * tileSize};
    dtNavMeshParams navParams = {};
    rcVcopy(navParams.orig, origin);
    navParams.tileWidth = navParams.tileHeight = tileSize;
    navParams.maxTiles = 4096;
    navParams.maxPolys = 32768;
    dtNavMesh* nav = dtAllocNavMesh();
    if (!nav || dtStatusFailed(nav->init(&navParams))) return 1;
    std::map<std::pair<int,int>, std::vector<int>> buckets;
    for (uint32_t i = 0; i < ntris; i++) {
        float lo[2] = {1e9f, 1e9f}, hi[2] = {-1e9f, -1e9f};
        for (int j = 0; j < 3; j++) {
            int idx = tris[i*3+j];
            if (idx < 0 || (uint32_t)idx >= nverts) return 1;
            for (int k = 0; k < 2; k++) { float v = verts[idx*3+k*2]; lo[k] = std::min(lo[k], v); hi[k] = std::max(hi[k], v); }
        }
        for (int tx = (int)floorf((lo[0]-4-origin[0])/tileSize); tx <= (int)floorf((hi[0]+4-origin[0])/tileSize); tx++)
        for (int ty = (int)floorf((lo[1]-4-origin[2])/tileSize); ty <= (int)floorf((hi[1]+4-origin[2])/tileSize); ty++) {
            auto& ids = buckets[{tx,ty}];
            ids.insert(ids.end(), {tris[i*3], tris[i*3+1], tris[i*3+2]});
        }
    }
    int totalNavSize = 0;
    for (const auto& bucket : buckets) {
        const int tx = bucket.first.first, ty = bucket.first.second;
        const auto& tileIndices = bucket.second;
        rcConfig cfg;
        memset(&cfg, 0, sizeof(cfg));
        cfg.cs = cs;
        cfg.ch = ch;
        cfg.walkableSlopeAngle = slope;
        cfg.walkableHeight = (int)ceilf(agentHeight / ch);
        cfg.walkableClimb = (int)floorf(agentClimb / ch + 0.0001f);
        cfg.walkableRadius = (int)ceilf(agentRadius / cs);
        cfg.maxEdgeLen = (int)(12.0f / cs);
        cfg.maxSimplificationError = 1.3f;
        cfg.minRegionArea = 8 * 8;
        cfg.mergeRegionArea = 20 * 20;
        cfg.maxVertsPerPoly = 6;
        cfg.detailSampleDist = 6.0f;
        cfg.detailSampleMaxError = 1.0f;
        cfg.tileSize = tileSize;
        cfg.borderSize = cfg.walkableRadius + 3;
        for (int k = 0; k < 3; k++) { cfg.bmin[k] = bmin[k]; cfg.bmax[k] = bmax[k]; }
        cfg.bmin[0] = origin[0] + tx * tileSize - cfg.borderSize;
        cfg.bmin[2] = origin[2] + ty * tileSize - cfg.borderSize;
        cfg.bmax[0] = origin[0] + (tx + 1) * tileSize + cfg.borderSize;
        cfg.bmax[2] = origin[2] + (ty + 1) * tileSize + cfg.borderSize;
        rcCalcGridSize(cfg.bmin, cfg.bmax, cfg.cs, &cfg.width, &cfg.height);


        rcContext ctx(false);
        rcHeightfield* solid = rcAllocHeightfield();
        if (!rcCreateHeightfield(&ctx, *solid, cfg.width, cfg.height, cfg.bmin, cfg.bmax, cfg.cs, cfg.ch)) {
            fprintf(stderr, "heightfield failed\n");
            return 1;
        }
        int tileTris = (int)tileIndices.size() / 3;
        std::vector<unsigned char> areas(tileTris);
        rcMarkWalkableTriangles(&ctx, cfg.walkableSlopeAngle, verts.data(), (int)nverts, tileIndices.data(), tileTris, areas.data());
        if (!rcRasterizeTriangles(&ctx, verts.data(), (int)nverts, tileIndices.data(), areas.data(), tileTris, *solid, cfg.walkableClimb)) {
            fprintf(stderr, "rasterize failed\n");
            return 1;
        }
        rcFilterLowHangingWalkableObstacles(&ctx, cfg.walkableClimb, *solid);
        rcFilterLedgeSpans(&ctx, cfg.walkableHeight, cfg.walkableClimb, *solid);
        rcFilterWalkableLowHeightSpans(&ctx, cfg.walkableHeight, *solid);

        rcCompactHeightfield* chf = rcAllocCompactHeightfield();
        if (!rcBuildCompactHeightfield(&ctx, cfg.walkableHeight, cfg.walkableClimb, *solid, *chf)) {
            fprintf(stderr, "compact failed\n");
            return 1;
        }
        if (!rcErodeWalkableArea(&ctx, cfg.walkableRadius, *chf)) return 1;
        if (!rcBuildDistanceField(&ctx, *chf)) return 1;
        if (!rcBuildRegions(&ctx, *chf, cfg.borderSize, cfg.minRegionArea, cfg.mergeRegionArea)) {
            fprintf(stderr, "regions failed\n");
            return 1;
        }
        if (!chf->spanCount) { rcFreeCompactHeightfield(chf); rcFreeHeightField(solid); continue; }
        rcContourSet* cset = rcAllocContourSet();
        if (!rcBuildContours(&ctx, *chf, cfg.maxSimplificationError, cfg.maxEdgeLen, *cset)) return 1;
        rcPolyMesh* pmesh = rcAllocPolyMesh();
        if (!rcBuildPolyMesh(&ctx, *cset, cfg.maxVertsPerPoly, *pmesh)) return 1;
        if (!pmesh->npolys) { rcFreePolyMesh(pmesh); rcFreeContourSet(cset); rcFreeCompactHeightfield(chf); rcFreeHeightField(solid); continue; }
        rcPolyMeshDetail* dmesh = rcAllocPolyMeshDetail();
        if (!rcBuildPolyMeshDetail(&ctx, *pmesh, *chf, cfg.detailSampleDist, cfg.detailSampleMaxError, *dmesh)) return 1;
        fprintf(stderr, "polys %d detailTris %d\n", pmesh->npolys, dmesh->ntris);

        for (int i = 0; i < pmesh->npolys; i++) {
            if (pmesh->areas[i] == RC_WALKABLE_AREA) {
                pmesh->flags[i] = 1;
            }
        }
        dtNavMeshCreateParams params;
        memset(&params, 0, sizeof(params));
        params.verts = pmesh->verts;
        params.vertCount = pmesh->nverts;
        params.polys = pmesh->polys;
        params.polyAreas = pmesh->areas;
        params.polyFlags = pmesh->flags;
        params.polyCount = pmesh->npolys;
        params.nvp = pmesh->nvp;
        params.detailMeshes = dmesh->meshes;
        params.detailVerts = dmesh->verts;
        params.detailVertsCount = dmesh->nverts;
        params.detailTris = dmesh->tris;
        params.detailTriCount = dmesh->ntris;
        params.walkableHeight = agentHeight;
        params.walkableRadius = agentRadius;
        params.walkableClimb = agentClimb;
        rcVcopy(params.bmin, pmesh->bmin);
        rcVcopy(params.bmax, pmesh->bmax);
        params.cs = cfg.cs;
        params.ch = cfg.ch;
        params.buildBvTree = true;
        params.tileX = tx; params.tileY = ty;

        unsigned char* navData = 0;
        int navSize = 0;
        if (!dtCreateNavMeshData(&params, &navData, &navSize)) {
            fprintf(stderr, "detour data failed\n");
            return 1;
        }
        rcFreePolyMeshDetail(dmesh);
        rcFreePolyMesh(pmesh);
        rcFreeContourSet(cset);
        rcFreeCompactHeightfield(chf);
        rcFreeHeightField(solid);
        if (dtStatusFailed(nav->addTile(navData, navSize, DT_TILE_FREE_DATA, 0, nullptr))) {
            fprintf(stderr, "addTile failed %d %d\n", tx, ty); return 1;
        }
        totalNavSize += navSize;
    }

    dtNavMeshQuery* query = dtAllocNavMeshQuery();
    if (dtStatusFailed(query->init(nav, 65535))) {
        fprintf(stderr, "query init failed\n");
        return 1;
    }
    fprintf(stderr, "navmesh bytes %d tiles %zu\n", totalNavSize, buckets.size());

    struct Place { std::string name; float p[3]; float radius; int main; };
    std::vector<Place> places;
    FILE* pf = fopen(argv[2], "r");
    if (!pf) return 1;
    char name[128];
    float x, y, z, radius; int requireMain;
    while (fscanf(pf, "%127s %f %f %f %f %d", name, &x, &y, &z, &radius, &requireMain) == 6) {
        Place place;
        place.name = name;
        wow_to_rc(x, y, z, place.p);
        place.radius = radius; place.main = requireMain;
        places.push_back(place);
    }
    fclose(pf);

    dtQueryFilter filter;
    filter.setIncludeFlags(1);
    filter.setExcludeFlags(0);
    // Centroids can land on props or cliffs. Reachable endpoints use the nearest
    // polygon of the main component within their stated spherical radius.
    std::unordered_map<dtPolyRef, int> component;
    std::vector<int> sizes;
    for (int ti = 0; ti < nav->getMaxTiles(); ti++) {
        const dtMeshTile* tile = static_cast<const dtNavMesh*>(nav)->getTile(ti);
        if (!tile->header) continue;
        const dtPolyRef base = nav->getPolyRefBase(tile);
        for (int pi = 0; pi < tile->header->polyCount; pi++) {
            dtPolyRef ref = base | (dtPolyRef)pi;
            if (component.count(ref)) continue;
            int id = (int)sizes.size(), count = 0;
            std::vector<dtPolyRef> todo = {ref};
            component[ref] = id;
            while (!todo.empty()) {
                dtPolyRef current = todo.back(); todo.pop_back(); count++;
                const dtMeshTile* t; const dtPoly* p;
                if (dtStatusFailed(nav->getTileAndPolyByRef(current, &t, &p))) return 1;
                for (unsigned int link = p->firstLink; link != DT_NULL_LINK; link = t->links[link].next) {
                    dtPolyRef other = t->links[link].ref;
                    if (other && !component.count(other)) { component[other] = id; todo.push_back(other); }
                }
            }
            sizes.push_back(count);
        }
    }
    std::vector<dtPolyRef> placeRefs(places.size());
    std::vector<float> snapped(places.size() * 3);
    if (sizes.empty()) { fprintf(stderr, "no walkable polygons\n"); return 1; }
    int mainComponent = (int)(std::max_element(sizes.begin(), sizes.end()) - sizes.begin());
    for (size_t i = 0; i < places.size(); i++) {
        float r = places[i].radius;
        const float ext[3] = {r, r, r};
        dtPolyRef candidates[16384]; int count = 0;
        dtStatus st = query->queryPolygons(places[i].p, ext, &filter, candidates, &count, 16384);
        if (dtStatusFailed(st) || (st & DT_BUFFER_TOO_SMALL)) return 1;
        int bestSize = -1; float bestDistance = 1e30f;
        for (int j = 0; j < count; j++) {
            float p[3];
            if (dtStatusFailed(query->closestPointOnPoly(candidates[j], places[i].p, p, nullptr))) continue;
            int size = sizes[component[candidates[j]]];
            float distance = dtVdistSqr(p, places[i].p);
            if (distance > r*r || (places[i].main && component[candidates[j]] != mainComponent)) continue;
            if (distance < bestDistance) {
                bestSize = size; bestDistance = distance; placeRefs[i] = candidates[j]; rcVcopy(&snapped[i*3], p);
            }
        }
        float x, y, z; rc_to_wow(&snapped[i*3], &x, &y, &z);
        fprintf(stderr, "PLACE %s component %d polygons %d snapped %.3f %.3f %.3f\n", places[i].name.c_str(), placeRefs[i] ? component[placeRefs[i]] : -1, bestSize, x, y, z);
    }
    FILE* out = fopen(argv[3], "w");
    if (!out) return 1;
    for (size_t i = 0; i < places.size(); i++) {
        float x, y, z; rc_to_wow(&snapped[i*3], &x, &y, &z);
        fprintf(out, "POINT %s %.3f %.3f %.3f %d\n", places[i].name.c_str(), x, y, z, placeRefs[i] ? component[placeRefs[i]] : -1);
    }
    std::vector<dtPolyRef> path(16384);
    std::vector<float> straight(4096 * 3);
    for (size_t i = 0; i < places.size(); i++) {
        for (size_t j = i + 1; j < places.size(); j++) {
            dtPolyRef sref = 0, eref = 0;
            float sp[3], ep[3];
            sref = placeRefs[i]; eref = placeRefs[j];
            rcVcopy(sp, &snapped[i*3]); rcVcopy(ep, &snapped[j*3]);
            const char* status = "FAIL";
            int scount = 0;
            if (sref && eref) {
                int pcount = 0;
                dtStatus st = query->findPath(sref, eref, sp, ep, &filter, path.data(), &pcount, (int)path.size());
                if (pcount) {
                    unsigned char flags[4096];
                    dtPolyRef refs[4096];
                    dtStatus straightStatus = query->findStraightPath(sp, ep, path.data(), pcount, straight.data(), flags, refs, &scount, 4096, 0);
                    status = dtStatusSucceed(st) && (st & (DT_PARTIAL_RESULT | DT_BUFFER_TOO_SMALL | DT_OUT_OF_NODES)) == 0 && path[pcount-1] == eref ? "OK" : "PARTIAL";
                    if (dtStatusFailed(straightStatus) || (straightStatus & DT_BUFFER_TOO_SMALL)) status = "FAIL";
                    if (!dtStatusSucceed(st) && !(st & DT_PARTIAL_RESULT)) status = "FAIL";
                }
            }
            fprintf(out, "PATH %s %s %s %d\n", places[i].name.c_str(), places[j].name.c_str(), status, scount);
            for (int k = 0; k < scount; k++) {
                float wx, wy, wz;
                rc_to_wow(&straight[k * 3], &wx, &wy, &wz);
                fprintf(out, "%.3f %.3f %.3f\n", wx, wy, wz);
            }
            fprintf(out, "END\n");
        }
    }
    fclose(out);
    fprintf(stderr, "paths %zu places\n", places.size());
    dtFreeNavMeshQuery(query);
    dtFreeNavMesh(nav);
    return 0;
}
