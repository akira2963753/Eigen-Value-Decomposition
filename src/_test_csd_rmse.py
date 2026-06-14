"""
Standalone RMSE test — does NOT modify Verification.ipynb.
Compares scaling methods on 11 patterns (Keep Y, Q5.12, 8 stages, 7 QR iters).
"""
import numpy as np
import scipy.io as sio

# --- same parameters as Verification.ipynb ---
HW_DW = 18
HW_FRAC = 12
HW_K_INV_FRAC = 14
HW_ITERATION = 8
EVD_MAX_ITER = 7
GIVENS_PAIRS = [(0, 1, 0), (0, 2, 0), (1, 2, 1)]
RMSE_THRESH = 1e-2
HW_MASK = (1 << HW_DW) - 1
ACC_W = HW_DW + 3  # CSD.v ACC_WIDTH
ACC_MASK = (1 << ACC_W) - 1

data = sio.loadmat("Final11Pattern.mat")
Matrix = data["Matrix"]


def to_s18(v):
    v = int(v) & HW_MASK
    return v - (1 << HW_DW) if v >= (1 << (HW_DW - 1)) else v


def to_s21(v):
    v = int(v) & ACC_MASK
    return v - (1 << ACC_W) if v >= (1 << (ACC_W - 1)) else v


def float_to_fix(f):
    return to_s18(int(np.floor(f * (1 << HW_FRAC))))


def fix_to_float(i):
    return i / (1 << HW_FRAC)


def cordic_scaling_factor(n_stages):
    K = 1.0
    for i in range(n_stages):
        K *= np.sqrt(1.0 + 2.0 ** (-2 * i))
    return K


K = cordic_scaling_factor(HW_ITERATION)
K_INV = int(np.floor((1.0 / K) * (1 << HW_K_INV_FRAC)))

# CSD coefficient (6-term, w_csd=14)
CSD6_COEFF = (
    2.0 ** -1 + 2.0 ** -3 + 2.0 ** -14
    - 2.0 ** -6 - 2.0 ** -9 - 2.0 ** -12
)


def k_inv_scale(v):
    return to_s18((v * K_INV) >> HW_K_INV_FRAC)


def csd_scale_v(v):
    """Bit-true model of src/scaling factor/CSD.v (6-term, ACC_WIDTH=DW+3)."""
    input_ext = to_s21(to_s18(v))
    scaled_sum = to_s21(
        (input_ext >> 1) + (input_ext >> 3) + (input_ext >> 14)
        - (input_ext >> 6) - (input_ext >> 9) - (input_ext >> 12)
    )
    return to_s18(scaled_sum)


def csd_scale_4term(v):
    """Old 4-term CSD: (>>1)+(>>3) - ((>>6)+(>>9))."""
    a = to_s18((v >> 1) + (v >> 3))
    b = to_s18((v >> 6) + (v >> 9))
    return to_s18(a - b)


def exact_k_scale(v):
    return to_s18(int(np.floor(v / K)))


def make_cordic(scale_fn):
    def hw_cordic_vectoring(in_x_fp, in_y_fp):
        in_x = float_to_fix(in_x_fp)
        in_y = float_to_fix(in_y_fp)
        flip = in_x < 0
        x = to_s18(-in_x) if flip else in_x
        y = to_s18(-in_y) if flip else in_y
        dir_bits = []
        for i in range(HW_ITERATION):
            dx, dy = y >> i, x >> i
            if y < 0:
                x, y = to_s18(x - dx), to_s18(y + dy)
                dir_bits.append(0)
            else:
                x, y = to_s18(x + dx), to_s18(y - dy)
                dir_bits.append(1)
        out_x = scale_fn(x)
        out_y = scale_fn(y)
        return fix_to_float(out_x), fix_to_float(out_y), {
            "flip": flip, "dir_bits": dir_bits,
            "out_x": out_x, "out_y": out_y,
        }

    def hw_cordic_rotation(in_x_fp, in_y_fp, dir_info):
        in_x = float_to_fix(in_x_fp)
        in_y = float_to_fix(in_y_fp)
        flip = dir_info["flip"]
        x = to_s18(-in_x) if flip else in_x
        y = to_s18(-in_y) if flip else in_y
        for i, d in enumerate(dir_info["dir_bits"]):
            dx, dy = y >> i, x >> i
            if d:
                x, y = to_s18(x + dx), to_s18(y - dy)
            else:
                x, y = to_s18(x - dx), to_s18(y + dy)
        ox, oy = scale_fn(x), scale_fn(y)
        return fix_to_float(ox), fix_to_float(oy), {}

    return hw_cordic_vectoring, hw_cordic_rotation


def hw_evd(A, vec_fn, rot_fn):
    n = A.shape[0]
    T = np.zeros((n, n))
    for i in range(n):
        for j in range(n):
            T[i, j] = fix_to_float(float_to_fix(A[i, j]))
    U = np.eye(n)
    for _it in range(EVD_MAX_ITER):
        R = T.copy()
        dir_infos = []
        for p, q, col in GIVENS_PAIRS:
            ox, oy, di = vec_fn(R[p, col], R[q, col])
            R[p, col] = ox
            R[q, col] = oy
            for m in range(col + 1, n):
                ox, oy, _ = rot_fn(R[p, m], R[q, m], di)
                R[p, m], R[q, m] = ox, oy
            dir_infos.append(di)
        RT = R.T.copy()
        for (p, q, _col), di in zip(GIVENS_PAIRS, dir_infos):
            for m in range(n):
                ox, oy, _ = rot_fn(RT[p, m], RT[q, m], di)
                RT[p, m], RT[q, m] = ox, oy
        T = RT
        for (p, q, _col), di in zip(GIVENS_PAIRS, dir_infos):
            for i in range(n):
                ox, oy, _ = rot_fn(U[i, p], U[i, q], di)
                U[i, p], U[i, q] = ox, oy
    return np.diag(T), U


def align_eigenpairs(lam_ref, V_ref, lam_hat, V_hat):
    idx = np.argsort(lam_hat)
    lam_hat = lam_hat[idx]
    V_hat = V_hat[:, idx]
    for i in range(len(lam_ref)):
        if np.dot(V_ref[:, i], V_hat[:, i]) < 0:
            V_hat[:, i] *= -1
    return lam_hat, V_hat


def rmse_lam(lam_ref, lam_hat):
    return float(np.sqrt(np.mean((lam_ref - lam_hat) ** 2)))


def rmse_vec(V_ref, V_hat):
    sq = sum(
        np.linalg.norm(V_ref[:, i] - V_hat[:, i]) ** 2
        for i in range(V_ref.shape[1])
    )
    return float(np.sqrt(sq / 9))


def evaluate_all(scale_fn, label):
    vec_fn, rot_fn = make_cordic(scale_fn)
    rows = []
    for s in range(Matrix.shape[2]):
        A = Matrix[:, :, s].astype(float)
        lam_ref, V_ref = np.linalg.eigh(A)
        lam_hat, V_hat = hw_evd(A, vec_fn, rot_fn)
        lam_hat, V_hat = align_eigenpairs(lam_ref, V_ref, lam_hat, V_hat)
        rl, rv = rmse_lam(lam_ref, lam_hat), rmse_vec(V_ref, V_hat)
        ok = rl < RMSE_THRESH and rv < RMSE_THRESH
        rows.append((s, rl, rv, ok))
    n_pass = sum(r[3] for r in rows)
    return label, rows, n_pass


# --- sanity: CSD.v vs k_inv per-value diff ---
diff_count = 0
max_diff = 0
for v in range(-50000, 50001, 17):
    a, b = csd_scale_v(v), k_inv_scale(v)
    if a != b:
        diff_count += 1
        max_diff = max(max_diff, abs(a - b))

print("=" * 78)
print("Scaling constant comparison (8 CORDIC stages)")
print(f"  K           = {K:.12f}")
print(f"  1/K         = {1/K:.12f}")
print(f"  K_INV       = {K_INV}  (Q0.{HW_K_INV_FRAC})")
print(f"  CSD6 coeff  = {CSD6_COEFF:.12f}  (rel err vs 1/K: "
      f"{abs(CSD6_COEFF - 1/K)/(1/K)*100:.5f}%)")
print(f"  csd_scale_v vs k_inv_scale: {diff_count} mismatches / sweep, max |diff|={max_diff} LSB")
print()
print(f"EVD: WL={HW_FRAC}, Stage={HW_ITERATION}, Iter={EVD_MAX_ITER}, Keep Y, threshold={RMSE_THRESH}")
print("=" * 78)

configs = [
    (csd_scale_v, "CSD.v 6-term (>>1,3,14 - >>6,9,12)"),
    (k_inv_scale, f"K_INV={K_INV} (>>{HW_K_INV_FRAC})  [current notebook]"),
    (exact_k_scale, "Exact floor(v/K)"),
    (csd_scale_4term, "Old 4-term CSD (reference)"),
]

all_results = {}
for fn, label in configs:
    lbl, rows, n_pass = evaluate_all(fn, label)
    all_results[label] = (rows, n_pass)

# Print per-pattern table
labels = [c[1] for c in configs]
hdr = f"{'Pat':>3}"
for lb in labels:
    short = lb[:22]
    hdr += f" | {short:^22}"
print(hdr)
print("-" * (5 + 25 * len(labels)))

for s in range(11):
    line = f"{s:3d}"
    for lb in labels:
        rl, rv, ok = all_results[lb][0][s][1:]
        st = "P" if ok else "F"
        line += f" | {rl:.4f}/{rv:.4f} {st}"
    print(line)

print("-" * (5 + 25 * len(labels)))
line = f"{'':>3}"
for lb in labels:
    n = all_results[lb][1]
    line += f" | {'PASS=' + str(n) + '/11':^22}"
print(line)
print("=" * 78)
