const CROCKFORD = "0123456789abcdefghjkmnpqrstvwxyz"

fn hex_to_int(hex: Str) -> Int {
    let mut value = 0
    let mut i = 0
    while i < hex.len() {
        let c = hex.slice(i, i + 1)
        value = value * 16
        if c == "0" { value = value + 0 }
        else if c == "1" { value = value + 1 }
        else if c == "2" { value = value + 2 }
        else if c == "3" { value = value + 3 }
        else if c == "4" { value = value + 4 }
        else if c == "5" { value = value + 5 }
        else if c == "6" { value = value + 6 }
        else if c == "7" { value = value + 7 }
        else if c == "8" { value = value + 8 }
        else if c == "9" { value = value + 9 }
        else if c == "a" { value = value + 10 }
        else if c == "b" { value = value + 11 }
        else if c == "c" { value = value + 12 }
        else if c == "d" { value = value + 13 }
        else if c == "e" { value = value + 14 }
        else if c == "f" { value = value + 15 }
        i = i + 1
    }
    value
}

fn base32_char(value: Int) -> Str {
    CROCKFORD.slice(value, value + 1)
}

pub fn generate_id() -> Str {
    let result = process_run("sh", ["-c", "head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n'"])
    if result.exit_code != 0 {
        // Fallback
        let seed = time_ms() * 1000 + getpid()
        let mut out: List[Str] = []
        let mut rem = seed
        let mut i = 0
        while i < 6 {
            out.push(base32_char(rem % 32))
            rem = rem / 32
            i = i + 1
        }
        return out.join("")
    }
    let hex = result.out.trim()
    // 5 bytes = 10 hex chars = 40 bits = 8 base32 chars
    let value = hex_to_int(hex)
    let mut out: List[Str] = []
    let mut rem = value
    let mut i = 0
    while i < 6 {
        out.push(base32_char(rem % 32))
        rem = rem / 32
        i = i + 1
    }
    out.join("")
}
