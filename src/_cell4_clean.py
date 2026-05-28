# Reference Eigen-Value Decomposition
def reference_evd(A):
    return np.linalg.eigh(A)


# Quantization (fraction bits only)
def quantize(z, b):
    return np.floor(z * 2**b) / 2**b


# --- CORDIC ---

def cordic_scaling_factor(n_stages):
    K = 1.0
    for i in range(n_stages):
        K *= np.sqrt(1.0 + 2.0 ** (-2 * i))
    return K


def to_csd(value, n_frac_bits):
    """Canonical CSD of value with n_frac_bits fractional precision."""
    n = int(np.round(value * 2**n_frac_bits))
    digits = {}
    pos_bit = -n_frac_bits
    while n != 0:
        if n & 1:
            d = -1 if (n & 3) == 3 else 1
            digits[pos_bit] = d
            n -= d
        n >>= 1
        pos_bit += 1
    csd_val = sum(d * 2.0**p for p, d in digits.items())
    return csd_val, digits


def csd_digits_to_shifts(digits):
    pos, neg = [], []
    for p, d in digits.items():
        if d == 0:
            continue
        shift = -p
        (pos if d > 0 else neg).append(shift)
    return tuple(sorted(pos)), tuple(sorted(neg))


def derive_csd_shifts(n_stages, w_csd):
    """Derive shift-add terms from canonical CSD of 1/K."""
    target = 1.0 / cordic_scaling_factor(n_stages)
    s_csd, digits = to_csd(target, w_csd)
    pos, neg = csd_digits_to_shifts(digits)
    return pos, neg, s_csd, target - s_csd, digits


def cordic_scale_csd(v, shifts_pos, shifts_neg):
    """Shift-add gain compensation: v * (sum 2^-s_pos - sum 2^-s_neg)."""
    v = int(v)
    return sum(v >> s for s in shifts_pos) - sum(v >> s for s in shifts_neg)


def cordic_scale_output(xi, yi, w_xy, cfg):
    if cfg.scale_mode == "CSD":
        xs = cordic_scale_csd(xi, cfg.csd_shifts_pos, cfg.csd_shifts_neg)
        ys = cordic_scale_csd(yi, cfg.csd_shifts_pos, cfg.csd_shifts_neg)
        return cfg.q(xs / (2**w_xy)), cfg.q(ys / (2**w_xy))
    k = cordic_scaling_factor(cfg.n_stages)
    return cfg.q(xi / (2**w_xy) / k), cfg.q(yi / (2**w_xy) / k)


def cordic_vectoring(x, y, cfg):
    w_xy = cfg.b
    dir_bits = []
    pre_flip = x < 0
    if pre_flip:
        x, y = -x, -y

    xi = int(np.floor(x * 2**w_xy))
    yi = int(np.floor(y * 2**w_xy))
    for i in range(cfg.n_stages):
        d = 1 if yi >= 0 else 0
        dir_bits.append(d)
        dX = yi >> i
        dY = xi >> i
        if d:
            xi += dX
            yi -= dY
        else:
            xi -= dX
            yi += dY

    x_out, y_out = cordic_scale_output(xi, yi, w_xy, cfg)
    return x_out, y_out, {"bits": dir_bits, "pre_flip": pre_flip}


def cordic_rotation(x, y, dir_info, cfg):
    w_xy = cfg.b
    if dir_info["pre_flip"]:
        x, y = -x, -y

    xi = int(np.floor(x * 2**w_xy))
    yi = int(np.floor(y * 2**w_xy))
    for i, d in enumerate(dir_info["bits"]):
        dX = yi >> i
        dY = xi >> i
        if d:
            xi += dX
            yi -= dY
        else:
            xi -= dX
            yi += dY

    return cordic_scale_output(xi, yi, w_xy, cfg)


# --- EVD config ---

class EVDConfig:
    def __init__(
        self,
        b=16,
        n_stages=16,
        mu=0.0,
        max_iter=8,
        scale_mode="K",
        csd_shifts_pos=None,
        csd_shifts_neg=None,
        csd_w_frac=9,
    ):
        self.b = b
        self.n_stages = n_stages
        self.mu = mu
        self.max_iter = max_iter
        self.scale_mode = scale_mode
        self.csd_w_frac = csd_w_frac
        if scale_mode == "CSD" and csd_shifts_pos is None:
            pos, neg, _, coeff_err, _ = derive_csd_shifts(n_stages, csd_w_frac)
            self.csd_shifts_pos = pos
            self.csd_shifts_neg = neg
            self.csd_coeff_err = coeff_err
        else:
            self.csd_shifts_pos = csd_shifts_pos or ()
            self.csd_shifts_neg = csd_shifts_neg or ()
            self.csd_coeff_err = None

    def q(self, z):
        return quantize(z, self.b)


# --- QR / Givens ---

GIVENS_PAIRS = [(0, 1, 0), (0, 2, 0), (1, 2, 1)]


def apply_givens_rows(M, p, q, col, cfg):
    M = np.array(M, dtype=float, copy=True)
    rp = cfg.q(M[p, :].copy())
    rq = cfg.q(M[q, :].copy())
    rp[col], rq[col], dir_info = cordic_vectoring(rp[col], rq[col], cfg)
    for m in range(col + 1, M.shape[1]):
        rp[m], rq[m] = cordic_rotation(rp[m], rq[m], dir_info, cfg)
    M[p, :] = rp
    M[q, :] = rq
    return M, dir_info


def qrd_phase2(T, cfg):
    R = cfg.q(np.array(T, dtype=float, copy=True))
    dir_infos = []
    for p, q, col in GIVENS_PAIRS:
        R, dir_info = apply_givens_rows(R, p, q, col, cfg)
        dir_infos.append(dir_info)
    return cfg.q(R), dir_infos


def qrd_rotation_pass(M, dir_infos, cfg, columns=False):
    M = np.array(M, dtype=float, copy=True)
    for (p, q, _col), dir_info in zip(GIVENS_PAIRS, dir_infos):
        if columns:
            cp = cfg.q(M[:, p].copy())
            cq = cfg.q(M[:, q].copy())
            for i in range(M.shape[0]):
                cp[i], cq[i] = cordic_rotation(cp[i], cq[i], dir_info, cfg)
            M[:, p] = cp
            M[:, q] = cq
        else:
            rp = cfg.q(M[p, :].copy())
            rq = cfg.q(M[q, :].copy())
            for m in range(M.shape[1]):
                rp[m], rq[m] = cordic_rotation(rp[m], rq[m], dir_info, cfg)
            M[p, :] = rp
            M[q, :] = rq
    return cfg.q(M)


def matrix_transpose(M, cfg):
    return cfg.q(np.array(M.T, dtype=float, copy=True))


def iterative_qr_evd(A, cfg):
    n = A.shape[0]
    T = cfg.q(np.array(A, dtype=float))
    U = cfg.q(np.eye(n))
    I = np.eye(n)
    for _ in range(cfg.max_iter):
        T_shifted = cfg.q(T - cfg.mu * I)
        R, dir_infos = qrd_phase2(T_shifted, cfg)
        RT = matrix_transpose(R, cfg)
        T = cfg.q(qrd_rotation_pass(RT, dir_infos, cfg) + cfg.mu * I)
        U = qrd_rotation_pass(U, dir_infos, cfg, columns=True)
    return np.diag(T), U, T, cfg.max_iter


# --- Evaluation ---

def align_eigenpairs(lam_ref, V_ref, lam_hat, V_hat):
    idx = np.argsort(lam_hat)
    lam_hat = lam_hat[idx]
    V_hat = V_hat[:, idx]
    for i in range(len(lam_ref)):
        if np.dot(V_ref[:, i], V_hat[:, i]) < 0:
            V_hat[:, i] *= -1
    return lam_hat, V_hat


def rmse_eigenvalues(lam_ref, lam_hat):
    return float(np.sqrt(np.mean((lam_ref - lam_hat) ** 2)))


def rmse_eigenvectors(V_ref, V_hat):
    sq = sum(np.linalg.norm(V_ref[:, i] - V_hat[:, i]) ** 2 for i in range(V_ref.shape[1]))
    return float(np.sqrt(sq / 9))


def evaluate_evd(A, cfg):
    lam_ref, V_ref = reference_evd(A)
    lam_hat, V_hat, _, n_iter = iterative_qr_evd(A, cfg)
    lam_hat, V_hat = align_eigenpairs(lam_ref, V_ref, lam_hat, V_hat)
    return {
        "rmse_lam": rmse_eigenvalues(lam_ref, lam_hat),
        "rmse_vec": rmse_eigenvectors(V_ref, V_hat),
        "n_iter": n_iter,
    }


def evaluate_all_patterns(Matrix, cfg):
    n_sets = Matrix.shape[2]
    rmse_lam = np.zeros(n_sets)
    rmse_vec = np.zeros(n_sets)
    for s in range(n_sets):
        r = evaluate_evd(Matrix[:, :, s], cfg)
        rmse_lam[s] = r["rmse_lam"]
        rmse_vec[s] = r["rmse_vec"]
    return rmse_lam, rmse_vec
