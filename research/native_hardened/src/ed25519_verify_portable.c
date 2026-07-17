/*
 * ed25519_verify_portable.c
 * OCRStudioSDK native hardening kit (authorized security research).
 *
 * Ed25519 signature verification for the attestation-JWT gate. Two backends,
 * selected at compile time (design: docs/superpowers/specs/2026-07-18-native-
 * hardened-sdk-patch-kit-design.md; contract: CLAUDE.md "Hardened-Auth Reference
 * Package"):
 *
 *   -DUSE_LIBSODIUM : thin wrapper over libsodium crypto_sign_verify_detached
 *                     (recommended for production; battle-tested).
 *   default         : self-contained portable verify derived from the public-
 *                     domain TweetNaCl gf[16] Ed25519 + SHA-512. No external
 *                     deps -> compiles anywhere a C99 compiler exists.
 *
 * HONEST SCOPE: the portable backend's constants are machine-generated and
 * Python-verified (scratchpad/gen_c.py: gf limbs match canonical TweetNaCl
 * byte-for-byte; SHA-512 K/H0 self-checked against hashlib). The algorithm was
 * prototyped and validated against PyNaCl before translation. It is compile-
 * validated only on CI (`make selftest` on Codemagic) against the deterministic
 * vectors in tests/hardened_test_vectors.h -- it is NOT built on the Windows
 * research host. Prefer -DUSE_LIBSODIUM where a vetted libsodium is available.
 *
 * Public API (see ed25519_verify.h):
 *   int hardened_ed25519_verify(const unsigned char sig[64],
 *                               const unsigned char *msg, unsigned long long mlen,
 *                               const unsigned char pk[32]);
 *   returns 1 iff the signature is valid, 0 otherwise.
 */

#include "ed25519_verify.h"

#ifdef USE_LIBSODIUM
/* ---- libsodium backend --------------------------------------------------- */
#include <sodium.h>

int hardened_ed25519_verify(const unsigned char sig[64],
                            const unsigned char *msg, unsigned long long mlen,
                            const unsigned char pk[32]) {
    if (sodium_init() < 0) return 0;
    return crypto_sign_verify_detached(sig, msg, (unsigned long long)mlen, pk) == 0 ? 1 : 0;
}

#else
/* ---- portable backend (TweetNaCl-derived, public domain) ----------------- */
#include <stddef.h>
#include "ed25519_constants.h"   /* SHA512_K, SHA512_H0, gf_D, gf_D2, gf_X, gf_Y, gf_I, ED_L */

typedef unsigned char u8;
typedef unsigned int  u32;

static const gf gf0 = {0};
static const gf gf1 = {1};

/* ---- SHA-512 (streaming) ------------------------------------------------- */
static u64 ror64(u64 x, int n) { return (x >> n) | (x << (64 - n)); }
static u64 ld_be64(const u8 *p) {
    u64 r = 0; int i;
    for (i = 0; i < 8; i++) r = (r << 8) | p[i];
    return r;
}
static void st_be64(u8 *p, u64 x) { int i; for (i = 7; i >= 0; i--) { p[i] = (u8)(x & 0xff); x >>= 8; } }

typedef struct { u64 st[8]; u8 buf[128]; size_t nbuf; u64 tot_lo, tot_hi; } sha512_ctx;

static void sha512_compress(u64 st[8], const u8 block[128]) {
    u64 w[80], a, b, c, d, e, f, g, h; int i;
    for (i = 0; i < 16; i++) w[i] = ld_be64(block + 8 * i);
    for (i = 16; i < 80; i++) {
        u64 s0 = ror64(w[i-15], 1) ^ ror64(w[i-15], 8) ^ (w[i-15] >> 7);
        u64 s1 = ror64(w[i-2], 19) ^ ror64(w[i-2], 61) ^ (w[i-2] >> 6);
        w[i] = w[i-16] + s0 + w[i-7] + s1;
    }
    a = st[0]; b = st[1]; c = st[2]; d = st[3];
    e = st[4]; f = st[5]; g = st[6]; h = st[7];
    for (i = 0; i < 80; i++) {
        u64 S1 = ror64(e, 14) ^ ror64(e, 18) ^ ror64(e, 41);
        u64 ch = (e & f) ^ (~e & g);
        u64 t1 = h + S1 + ch + SHA512_K[i] + w[i];
        u64 S0 = ror64(a, 28) ^ ror64(a, 34) ^ ror64(a, 39);
        u64 maj = (a & b) ^ (a & c) ^ (b & c);
        u64 t2 = S0 + maj;
        h = g; g = f; f = e; e = d + t1; d = c; c = b; b = a; a = t1 + t2;
    }
    st[0]+=a; st[1]+=b; st[2]+=c; st[3]+=d; st[4]+=e; st[5]+=f; st[6]+=g; st[7]+=h;
}
static void sha512_init(sha512_ctx *c) {
    int i; for (i = 0; i < 8; i++) c->st[i] = SHA512_H0[i];
    c->nbuf = 0; c->tot_lo = 0; c->tot_hi = 0;
}
static void sha512_update(sha512_ctx *c, const u8 *data, size_t len) {
    u64 prev = c->tot_lo;
    c->tot_lo += (u64)len;
    if (c->tot_lo < prev) c->tot_hi++;
    while (len) {
        size_t n = 128 - c->nbuf;
        if (n > len) n = len;
        { size_t i; for (i = 0; i < n; i++) c->buf[c->nbuf + i] = data[i]; }
        c->nbuf += n; data += n; len -= n;
        if (c->nbuf == 128) { sha512_compress(c->st, c->buf); c->nbuf = 0; }
    }
}
static void sha512_final(sha512_ctx *c, u8 out[64]) {
    /* 128-bit big-endian bit length */
    u64 bits_lo = c->tot_lo << 3;
    u64 bits_hi = (c->tot_hi << 3) | (c->tot_lo >> 61);
    u8 pad = 0x80; int i;
    sha512_update(c, &pad, 1);
    { u8 z = 0; while (c->nbuf != 112) sha512_update(c, &z, 1); }
    { u8 lb[16]; st_be64(lb, bits_hi); st_be64(lb + 8, bits_lo); sha512_update(c, lb, 16); }
    for (i = 0; i < 8; i++) st_be64(out + 8 * i, c->st[i]);
}

/* ---- field arithmetic (radix 2^16 gf[16]) -------------------------------- */
static void set25519(gf r, const gf a) { int i; for (i = 0; i < 16; i++) r[i] = a[i]; }
static void car25519(gf o) {
    int i; i64 c;
    for (i = 0; i < 16; i++) {
        o[i] += (1LL << 16);
        c = o[i] >> 16;
        o[(i + 1) * (i < 15)] += c - 1 + 37 * (c - 1) * (i == 15);
        o[i] -= c << 16;
    }
}
static void sel25519(gf p, gf q, int b) {
    i64 t, i, c = ~(b - 1);
    for (i = 0; i < 16; i++) { t = c & (p[i] ^ q[i]); p[i] ^= t; q[i] ^= t; }
}
static int crypto_verify_32(const u8 *x, const u8 *y) {
    u32 d = 0; int i;
    for (i = 0; i < 32; i++) d |= (u32)(x[i] ^ y[i]);
    return (int)((1 & ((d - 1) >> 8)) - 1);   /* 0 if equal, -1 if different */
}
static void pack25519(u8 *o, const gf n) {
    int i, j, b; gf m, t;
    for (i = 0; i < 16; i++) t[i] = n[i];
    car25519(t); car25519(t); car25519(t);
    for (j = 0; j < 2; j++) {
        m[0] = t[0] - 0xffed;
        for (i = 1; i < 15; i++) { m[i] = t[i] - 0xffff - ((m[i-1] >> 16) & 1); m[i-1] &= 0xffff; }
        m[15] = t[15] - 0x7fff - ((m[14] >> 16) & 1);
        b = (int)((m[15] >> 16) & 1);
        m[14] &= 0xffff;
        sel25519(t, m, 1 - b);
    }
    for (i = 0; i < 16; i++) { o[2*i] = (u8)(t[i] & 0xff); o[2*i+1] = (u8)(t[i] >> 8); }
}
static int neq25519(const gf a, const gf b) { u8 c[32], d[32]; pack25519(c, a); pack25519(d, b); return crypto_verify_32(c, d); }
static u8  par25519(const gf a) { u8 d[32]; pack25519(d, a); return d[0] & 1; }
static void unpack25519(gf o, const u8 *n) { int i; for (i = 0; i < 16; i++) o[i] = n[2*i] + ((i64)n[2*i+1] << 8); o[15] &= 0x7fff; }
static void A(gf o, const gf a, const gf b) { int i; for (i = 0; i < 16; i++) o[i] = a[i] + b[i]; }
static void Z(gf o, const gf a, const gf b) { int i; for (i = 0; i < 16; i++) o[i] = a[i] - b[i]; }
static void M(gf o, const gf a, const gf b) {
    i64 i, j, t[31];
    for (i = 0; i < 31; i++) t[i] = 0;
    for (i = 0; i < 16; i++) for (j = 0; j < 16; j++) t[i+j] += a[i] * b[j];
    for (i = 0; i < 15; i++) t[i] += 38 * t[i+16];
    for (i = 0; i < 16; i++) o[i] = t[i];
    car25519(o); car25519(o);
}
static void S(gf o, const gf a) { M(o, a, a); }
static void inv25519(gf o, const gf in) { gf c; int a; set25519(c, in); for (a = 253; a >= 0; a--) { S(c, c); if (a != 2 && a != 4) M(c, c, in); } set25519(o, c); }
static void pow2523(gf o, const gf in) { gf c; int a; set25519(c, in); for (a = 250; a >= 0; a--) { S(c, c); if (a != 1) M(c, c, in); } set25519(o, c); }

/* ---- group operations ---------------------------------------------------- */
static void add(gf p[4], gf q[4]) {
    gf a, b, c, d, t, e, f, g, h;
    Z(a, p[1], p[0]); Z(t, q[1], q[0]); M(a, a, t);
    A(b, p[0], p[1]); A(t, q[0], q[1]); M(b, b, t);
    M(c, p[3], q[3]); M(c, c, gf_D2);
    M(d, p[2], q[2]); A(d, d, d);
    Z(e, b, a); Z(f, d, c); A(g, d, c); A(h, b, a);
    M(p[0], e, f); M(p[1], h, g); M(p[2], g, f); M(p[3], e, h);
}
static void cswap(gf p[4], gf q[4], u8 b) { int i; for (i = 0; i < 4; i++) sel25519(p[i], q[i], b); }
static void pack(u8 *r, gf p[4]) {
    gf tx, ty, zi;
    inv25519(zi, p[2]);
    M(tx, p[0], zi); M(ty, p[1], zi);
    pack25519(r, ty);
    r[31] ^= par25519(tx) << 7;
}
static void scalarmult(gf p[4], gf q[4], const u8 *s) {
    int i;
    set25519(p[0], gf0); set25519(p[1], gf1); set25519(p[2], gf1); set25519(p[3], gf0);
    for (i = 255; i >= 0; --i) {
        u8 b = (u8)((s[i >> 3] >> (i & 7)) & 1);
        cswap(p, q, b); add(q, p); add(p, p); cswap(p, q, b);
    }
}
static void scalarbase(gf p[4], const u8 *s) {
    gf q[4];
    set25519(q[0], gf_X); set25519(q[1], gf_Y); set25519(q[2], gf1); M(q[3], gf_X, gf_Y);
    scalarmult(p, q, s);
}
static int unpackneg(gf r[4], const u8 p[32]) {
    gf t, chk, num, den, den2, den4, den6;
    set25519(r[2], gf1);
    unpack25519(r[1], p);
    S(num, r[1]);
    M(den, num, gf_D);
    Z(num, num, r[2]);
    A(den, r[2], den);
    S(den2, den); S(den4, den2); M(den6, den4, den2);
    M(t, den6, num); M(t, t, den);
    pow2523(t, t);
    M(t, t, num); M(t, t, den); M(t, t, den);
    M(r[0], t, den);
    S(chk, r[0]); M(chk, chk, den);
    if (neq25519(chk, num)) M(r[0], r[0], gf_I);
    S(chk, r[0]); M(chk, chk, den);
    if (neq25519(chk, num)) return -1;
    if (par25519(r[0]) == (p[31] >> 7)) Z(r[0], gf0, r[0]);
    M(r[3], r[0], r[1]);
    return 0;
}

/* ---- scalar reduction mod L ---------------------------------------------- */
static void modL(u8 *r, i64 x[64]) {
    i64 carry, i, j;
    for (i = 63; i >= 32; --i) {
        carry = 0;
        for (j = i - 32; j < i - 12; ++j) {
            x[j] += carry - 16 * x[i] * ED_L[j - (i - 32)];
            carry = (x[j] + 128) >> 8;
            x[j] -= carry << 8;
        }
        x[j] += carry;
        x[i] = 0;
    }
    carry = 0;
    for (j = 0; j < 32; ++j) { x[j] += carry - (x[31] >> 4) * ED_L[j]; carry = x[j] >> 8; x[j] &= 255; }
    for (j = 0; j < 32; ++j) x[j] -= carry * ED_L[j];
    for (i = 0; i < 32; ++i) { x[i+1] += x[i] >> 8; r[i] = (u8)(x[i] & 255); }
}
static void reduce(u8 *r) {
    i64 x[64], i;
    for (i = 0; i < 64; ++i) x[i] = (i64)(u64)r[i];
    for (i = 0; i < 64; ++i) r[i] = 0;
    modL(r, x);
}

/* ---- public entry -------------------------------------------------------- */
int hardened_ed25519_verify(const unsigned char sig[64],
                            const unsigned char *msg, unsigned long long mlen,
                            const unsigned char pk[32]) {
    u8 h[64], t[32];
    gf p[4], q[4];
    sha512_ctx ctx;
    if (unpackneg(q, pk)) return 0;               /* pk not a valid point */
    sha512_init(&ctx);
    sha512_update(&ctx, sig, 32);                 /* R */
    sha512_update(&ctx, pk, 32);                  /* A */
    sha512_update(&ctx, msg, (size_t)mlen);       /* M */
    sha512_final(&ctx, h);
    reduce(h);
    scalarmult(p, q, h);
    scalarbase(q, sig + 32);                       /* s*B */
    add(p, q);
    pack(t, p);
    return crypto_verify_32(sig, t) == 0 ? 1 : 0;  /* R ?= s*B - h*A */
}

#endif /* USE_LIBSODIUM */
