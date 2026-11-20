"""Read a WDC5 DB2 from the Forever client. Column names come from the caller.

The header matches DBCD's WDC5Reader: 4-byte magic, version, a 128-byte schema
name, then the usual counts. Bit packing matches DBCD's BitReader (a little-endian
word shifted so the next bits sit at the top).
"""

import struct
from pathlib import Path

NONE, IMMEDIATE, COMMON, PALLET, PALLET_ARRAY, SIGNED = range(6)


def _u64(data, bitpos, num_bits):
    byte_off = bitpos >> 3
    chunk = data[byte_off : byte_off + 8]
    if len(chunk) < 8:
        chunk += b"\x00" * (8 - len(chunk))
    val = int.from_bytes(chunk, "little")
    shift = 64 - num_bits - (bitpos & 7)
    return ((val << shift) & 0xFFFFFFFFFFFFFFFF) >> (64 - num_bits)


def _cstring(blob, index):
    if index < 0 or index >= len(blob):
        return ""
    end = blob.find(b"\x00", index)
    if end < 0:
        end = len(blob)
    return blob[index:end].decode("utf-8", "replace")


def _as_float(raw):
    return struct.unpack("<f", struct.pack("<I", raw & 0xFFFFFFFF))[0]


def load(path, columns, strings=(), floats=()):
    """Return a list of dicts, one per row.

    columns is the DBD field order. An entry is a name, or (name, count) when
    the field is an array; array elements are written as name_0, name_1, ...
    strings and floats name the scalar columns (and array bases) to decode.
    """
    data = Path(path).read_bytes()
    if data[:4] != b"WDC5":
        raise ValueError(f"{path} is not WDC5")
    schema = data[8:136].split(b"\x00", 1)[0].decode()
    pos = 136
    (
        record_count,
        field_count,
        record_size,
        _string_table_size,
        _table_hash,
        _layout_hash,
        _min_id,
        _max_id,
        _locale,
    ) = struct.unpack_from("<9i", data, pos)
    pos += 36
    _flags, id_index = struct.unpack_from("<HH", data, pos)
    pos += 4
    (
        _total_fields,
        _packed_offset,
        _lookup_count,
        _column_meta_size,
        _common_size,
        _pallet_size,
        section_count,
    ) = struct.unpack_from("<7i", data, pos)
    pos += 28
    specs = []
    for column in columns:
        if isinstance(column, tuple):
            specs.append((column[0], column[1]))
        else:
            specs.append((column, 1))

    sections = []
    for _ in range(section_count):
        tact, file_off, num, str_size, rec_end, index_size, parent_size, offset_map, copy_count = struct.unpack_from(
            "<Q8i", data, pos
        )
        pos += 40
        sections.append(
            {
                "tact": tact,
                "file_off": file_off,
                "num": num,
                "str_size": str_size,
                "index_size": index_size,
                "parent_size": parent_size,
                "copy_count": copy_count,
            }
        )

    field_meta = []
    for _ in range(field_count):
        bits, offset = struct.unpack_from("<hh", data, pos)
        pos += 4
        field_meta.append((bits, offset))

    columns_meta = []
    for _ in range(field_count):
        record_offset, size, extra, comp, a, b, c = struct.unpack_from("<HHIIIII", data, pos)
        pos += 24
        columns_meta.append(
            {"off": record_offset, "size": size, "extra": extra, "comp": comp, "a": a, "b": b, "c": c}
        )

    pallets = [None] * field_count
    for i, col in enumerate(columns_meta):
        if col["comp"] == PALLET:
            n = col["extra"] // 4
            pallets[i] = list(struct.unpack_from(f"<{n}I", data, pos))
            pos += col["extra"]
    for i, col in enumerate(columns_meta):
        if col["comp"] == PALLET_ARRAY:
            n = col["extra"] // 4
            pallets[i] = list(struct.unpack_from(f"<{n}I", data, pos))
            pos += col["extra"]

    commons = [None] * field_count
    for i, col in enumerate(columns_meta):
        if col["comp"] == COMMON:
            table = {}
            for _ in range(col["extra"] // 8):
                key, val = struct.unpack_from("<iI", data, pos)
                pos += 8
                table[key] = val
            commons[i] = table

    rows = []
    for section in sections:
        if section["tact"]:
            raise ValueError(f"encrypted DB2 section is unsupported: {path}")
        base = section["file_off"]
        records = data[base : base + section["num"] * record_size]
        str_off = base + section["num"] * record_size
        strings_blob = data[str_off : str_off + section["str_size"]]
        cursor = str_off + section["str_size"]
        index = []
        if section["index_size"]:
            n = section["index_size"] // 4
            index = list(struct.unpack_from(f"<{n}i", data, cursor))
            cursor += section["index_size"]
        copies = []
        for _ in range(section["copy_count"]):
            copies.append(struct.unpack_from("<ii", data, cursor))
            cursor += 8

        # An index block means the id column is not stored in the record, so the
        # file's field meta lines up with the other columns only.
        external_id = bool(section["index_size"])
        if external_id and len(specs) != field_count + 1:
            raise ValueError(f"{path} index id needs {field_count + 1} columns, got {len(specs)}")
        if not external_id and len(specs) != field_count:
            raise ValueError(f"{path} has {field_count} fields, not {len(specs)}")

        def decode_record(rec_i, row_id):
            bitpos = 0
            rec = records[rec_i * record_size : (rec_i + 1) * record_size]
            padded = rec + b"\x00" * 8
            out = {}
            meta_i = 0
            for fi, (name, count) in enumerate(specs):
                if external_id and fi == id_index:
                    out[name] = row_id
                    continue
                col = columns_meta[meta_i]
                bits = field_meta[meta_i][0]
                meta_i += 1
                comp = col["comp"]
                got = []
                if comp == NONE:
                    width = 32 - bits
                    if width <= 0:
                        width = col["b"] or 32
                    n = count if count > 1 else (col["size"] // width if width and col["size"] >= width else 1)
                    for _ in range(n):
                        raw = _u64(padded, bitpos, width)
                        before = bitpos
                        bitpos += width
                        if name in strings:
                            rel = (rec_i * record_size) - (section["num"] * record_size)
                            got.append(_cstring(strings_blob, rel + (before >> 3) + raw))
                        elif name in floats:
                            got.append(_as_float(raw))
                        else:
                            got.append(raw)
                elif comp in (IMMEDIATE, SIGNED):
                    width = col["b"]
                    raw = _u64(padded, bitpos, width)
                    bitpos += width
                    if comp == SIGNED and width and raw >> (width - 1):
                        raw -= 1 << width
                    got = [_as_float(raw) if name in floats else raw]
                elif comp == COMMON:
                    raw = commons[meta_i - 1].get(row_id if row_id is not None else 0, col["a"])
                    if name in floats:
                        raw = _as_float(raw)
                    got = [raw]
                elif comp in (PALLET, PALLET_ARRAY):
                    width = col["b"]
                    n = col["c"] if comp == PALLET_ARRAY and col["c"] else 1
                    idx = _u64(padded, bitpos, width)
                    bitpos += width
                    for j in range(n):
                        raw = pallets[meta_i - 1][idx * n + j]
                        got.append(_as_float(raw) if name in floats else raw)
                else:
                    raise ValueError(f"compression {comp} on {name}")
                if fi == id_index and row_id is None:
                    row_id = got[0]
                if len(got) == 1 and count == 1:
                    out[name] = got[0]
                else:
                    for j, value in enumerate(got):
                        out[f"{name}_{j}"] = value
            return out, row_id

        by_id = {}
        for rec_i in range(section["num"]):
            row_id = index[rec_i] if index else None
            out, row_id = decode_record(rec_i, row_id)
            by_id[row_id] = out
            rows.append(out)
        for dest, src in copies:
            if dest != src and src in by_id:
                clone = dict(by_id[src])
                id_name = specs[id_index][0]
                clone[id_name] = dest
                by_id[dest] = clone
                rows.append(clone)
    return rows
