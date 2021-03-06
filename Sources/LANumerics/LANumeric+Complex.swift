import Accelerate
import Numerics

fileprivate func recast<U, V>(_ ptr : UnsafeMutablePointer<U>) -> UnsafeMutablePointer<V> {
    let p = UnsafeMutableRawPointer(ptr)
    return p.assumingMemoryBound(to: V.self)
}

fileprivate func recast<U, V>(_ ptr : UnsafePointer<U>) -> UnsafePointer<V> {
    let p = UnsafeRawPointer(ptr)
    return p.assumingMemoryBound(to: V.self)
}

extension Complex {
    
    static func dispatch<R>(float : () -> R, double : () -> R) -> R {
        if RealType.self == Float.self {
            return float()
        } else if RealType.self == Double.self {
            return double()
        } else {
            fatalError("cannot dispatch on Complex.RealType == \(RealType.self)")
        }
    }

}

extension Complex : MatrixElement {

    public var adjoint : Complex { return conjugate }

}

extension Complex : LANumeric, ExpressibleByFloatLiteral where RealType : LANumeric {
        
    public typealias FloatLiteralType = Double
    
    public init(floatLiteral: Self.FloatLiteralType) {
        var x : RealType = 0
        Complex.dispatch(
            float: { x = Float(floatLiteral) as! RealType },
            double: { x = Double(floatLiteral) as! RealType }
        )
        self.init(x)
    }
    
    public var manhattanLength : Magnitude { return real.magnitude + imaginary.magnitude }

    public init(magnitude: Self.Magnitude) {
        self = Complex(magnitude, 0)
    }

    public var toInt : Int {
        precondition(imaginary.isZero)
        return Complex.dispatch (
            float: { return Int(real as! Float) },
            double: { return Int(real as! Double) }
        )
    }

    public static func random(in range: ClosedRange<RealType>) -> Self {
        return Complex.dispatch (
            float: {
                let r = range as! ClosedRange<Float>
                let x = Float.random(in: r) as! RealType
                let y = Float.random(in: r) as! RealType
                return Complex(x, y)
            },
            double: {
                let r = range as! ClosedRange<Double>
                let x = Double.random(in: r) as! RealType
                let y = Double.random(in: r) as! RealType
                return Complex(x, y)
            }
        )
    }
    
    public static func randomWhole(in range : ClosedRange<Int>) -> Self {
        return Complex.dispatch (
            float: {
                let x = Float.randomWhole(in: range) as! RealType
                let y = Float.randomWhole(in: range) as! RealType
                return Complex(x, y)
            },
            double: {
                let x = Double.randomWhole(in: range) as! RealType
                let y = Double.randomWhole(in: range) as! RealType
                return Complex(x, y)
            }
        )
    }

    public static func blas_asum(_ N: Int32, _ X: UnsafePointer<Self>, _ incX: Int32) -> Self.Magnitude {
        return Complex.dispatch (
            float: { cblas_scasum(N, X, incX) as! Self.Magnitude },
            double: { cblas_dzasum(N, X, incX) as! Self.Magnitude }
        )
    }
    
    public static func blas_nrm2(_ N: Int32, _ X: UnsafePointer<Self>, _ incX: Int32) -> Self.Magnitude {
        return Complex.dispatch (
            float: { cblas_scnrm2(N, X, incX) as! Self.Magnitude },
            double: { cblas_dznrm2(N, X, incX) as! Self.Magnitude }
        )
    }
    
    public static func blas_scal(_ N : Int32, _ alpha : Self, _ X : UnsafeMutablePointer<Self>, _ incX : Int32) {
        var _alpha = alpha
        dispatch(
            float: { cblas_cscal(N, &_alpha, X, incX) },
            double: { cblas_zscal(N, &_alpha, X, incX) }
        )
    }

    public static func blas_axpby(_ N : Int32, _ alpha : Self, _ X : UnsafePointer<Self>, _ incX : Int32, _ beta : Self, _ Y : UnsafeMutablePointer<Self>, _ incY : Int32) {
        var _alpha = alpha
        var _beta = beta
        dispatch(
            float: { catlas_caxpby(N, &_alpha, X, incX, &_beta, Y, incY) },
            double: { catlas_zaxpby(N, &_alpha, X, incX, &_beta, Y, incY) }
        )
    }
    
    public static func blas_iamax(_ N : Int32, _ X : UnsafePointer<Self>, _ incX : Int32) -> Int32 {
        dispatch(
            float: { cblas_icamax(N, X, incX) },
            double: { cblas_izamax(N, X, incX) }
        )
    }

    public static func blas_iamax_inf(_ N : Int32, _ X : UnsafePointer<Self>, _ incX : Int32) -> Int32 {
        dispatch(
            float: {
                let R : UnsafePointer<Float> = recast(X)
                let I = R + 1
                let inc = 2 * incX
                let i1 = cblas_isamax(N, R, inc)
                let i2 = cblas_isamax(N, I, inc)
                let abs1 = abs(R[Int(2 * i1)])
                let abs2 = abs(I[Int(2 * i2)])
                if abs1 == abs2 {
                    return min(i1, i2)
                } else if abs1 < abs2 {
                    return i2
                } else {
                    return i1
                }
            },
            double: {
                let R : UnsafePointer<Double> = recast(X)
                let I = R + 1
                let inc = 2 * incX
                let i1 = cblas_idamax(N, R, inc)
                let i2 = cblas_idamax(N, I, inc)
                let abs1 = abs(R[Int(2 * i1)])
                let abs2 = abs(I[Int(2 * i2)])
                if abs1 == abs2 {
                    return min(i1, i2)
                } else if abs1 < abs2 {
                    return i2
                } else {
                    return i1
                }
            }
        )
    }
    
    public static func blas_dot(_ N : Int32, _ X : UnsafePointer<Self>, _ incX : Int32, _ Y : UnsafePointer<Self>, _ incY : Int32) -> Self {
        return dispatch(
            float: {
                var result : Self = 0
                cblas_cdotu_sub(N, X, incX, Y, incY, &result)
                return result
            },
            double: {
                var result : Self = 0
                cblas_zdotu_sub(N, X, incX, Y, incY, &result)
                return result
            }
        )
    }
    
    public static func blas_adjointDot(_ N : Int32, _ X : UnsafePointer<Self>, _ incX : Int32, _ Y : UnsafePointer<Self>, _ incY : Int32) -> Self {
        dispatch(
            float: {
                var result : Self = 0
                cblas_cdotc_sub(N, X, incX, Y, incY, &result)
                return result
            },
            double: {
                var result : Self = 0
                cblas_zdotc_sub(N, X, incX, Y, incY, &result)
                return result
            }
        )
    }

    public static func blas_gemm(_ Order : CBLAS_ORDER, _ TransA : CBLAS_TRANSPOSE, _ TransB : CBLAS_TRANSPOSE,
                                 _ M : Int32, _ N : Int32, _ K : Int32,
                                 _ alpha : Self, _ A : UnsafePointer<Self>, _ lda : Int32, _ B : UnsafePointer<Self>, _ ldb : Int32,
                                 _ beta : Self, _ C : UnsafeMutablePointer<Self>, _ ldc : Int32)
    {
        var _alpha = alpha
        var _beta = beta
        dispatch(
            float: { cblas_cgemm(Order, TransA, TransB, M, N, K, &_alpha, A, lda, B, ldb, &_beta, C, ldc) },
            double: { cblas_zgemm(Order, TransA, TransB, M, N, K, &_alpha, A, lda, B, ldb, &_beta, C, ldc) }
        )
    }

    public static func blas_gemv(_ Order : CBLAS_ORDER, _ TransA : CBLAS_TRANSPOSE, _ M : Int32, _ N : Int32,
                                 _ alpha : Self, _ A : UnsafePointer<Self>, _ lda : Int32,
                                 _ X : UnsafePointer<Self>, _ incX : Int32,
                                 _ beta : Self, _ Y : UnsafeMutablePointer<Self>, _ incY : Int32)
    {
        var _alpha = alpha
        var _beta = beta
        dispatch(
            float: { cblas_cgemv(Order, TransA, M, N, &_alpha, A, lda, X, incX, &_beta, Y, incY) },
            double: { cblas_zgemv(Order, TransA, M, N, &_alpha, A, lda, X, incX, &_beta, Y, incY) }
        )
    }

    public static func blas_ger(_ Order : CBLAS_ORDER, _ M : Int32, _ N : Int32,
                                _ alpha : Self, _ X : UnsafePointer<Self>, _ incX : Int32,
                                _ Y : UnsafePointer<Self>, _ incY : Int32,
                                _ A : UnsafeMutablePointer<Self>, _ lda : Int32)
    {
        var _alpha = alpha
        dispatch(
            float: { cblas_cgeru(Order, M, N, &_alpha, X, incX, Y, incY, A, lda) },
            double: { cblas_zgeru(Order, M, N, &_alpha, X, incX, Y, incY, A, lda)  }
        )
    }

    public static func blas_gerAdjoint(_ Order : CBLAS_ORDER, _ M : Int32, _ N : Int32,
                                       _ alpha : Self, _ X : UnsafePointer<Self>, _ incX : Int32,
                                       _ Y : UnsafePointer<Self>, _ incY : Int32,
                                       _ A : UnsafeMutablePointer<Self>, _ lda : Int32)
    {
        var _alpha = alpha
        dispatch(
            float: { cblas_cgerc(Order, M, N, &_alpha, X, incX, Y, incY, A, lda) },
            double: { cblas_zgerc(Order, M, N, &_alpha, X, incX, Y, incY, A, lda)  }
        )
    }
    
    public static func lapack_gesv(_ n : UnsafeMutablePointer<IntLA>, _ nrhs : UnsafeMutablePointer<IntLA>,
                                   _ a : UnsafeMutablePointer<Self>, _ lda : UnsafeMutablePointer<IntLA>,
                                   _ ipiv : UnsafeMutablePointer<IntLA>,
                                   _ b : UnsafeMutablePointer<Self>, _ ldb : UnsafeMutablePointer<IntLA>,
                                   _ info : UnsafeMutablePointer<IntLA>) -> Int32
    {
        dispatch(
            float: { cgesv_(n, nrhs, recast(a), lda, ipiv, recast(b), ldb, info) },
            double: { zgesv_(n, nrhs, recast(a), lda, ipiv, recast(b), ldb, info) }
        )
    }

    public static func lapack_gels(_ trans : Transpose,
                                   _ m : UnsafeMutablePointer<IntLA>, _ n : UnsafeMutablePointer<IntLA>, _ nrhs : UnsafeMutablePointer<IntLA>,
                                   _ a : UnsafeMutablePointer<Self>, _ lda : UnsafeMutablePointer<IntLA>,
                                   _ b : UnsafeMutablePointer<Self>, _ ldb : UnsafeMutablePointer<IntLA>,
                                   _ work : UnsafeMutablePointer<Self>, _ lwork : UnsafeMutablePointer<IntLA>,
                                   _ info : UnsafeMutablePointer<IntLA>) -> Int32
    {
        var trans = trans.blas(complex: true)
        return dispatch(
            float: { cgels_(&trans, m, n, nrhs, recast(a), lda, recast(b), ldb, recast(work), lwork, info) },
            double: { zgels_(&trans, m, n, nrhs, recast(a), lda, recast(b), ldb, recast(work), lwork, info) }
        )
    }

    public static func lapack_gesvd(_ jobu : UnsafeMutablePointer<Int8>, _ jobvt : UnsafeMutablePointer<Int8>,
                                    _ m : UnsafeMutablePointer<IntLA>, _ n : UnsafeMutablePointer<IntLA>,
                                    _ a : UnsafeMutablePointer<Self>, _ lda : UnsafeMutablePointer<IntLA>,
                                    _ s : UnsafeMutablePointer<Self.Magnitude>,
                                    _ u : UnsafeMutablePointer<Self>, _ ldu : UnsafeMutablePointer<IntLA>,
                                    _ vt : UnsafeMutablePointer<Self>, _ ldvt : UnsafeMutablePointer<IntLA>,
                                    _ work : UnsafeMutablePointer<Self>, _ lwork : UnsafeMutablePointer<IntLA>,
                                    _ info : UnsafeMutablePointer<IntLA>) -> Int32
    {
        return dispatch(
            float: {
                var rwork = [Float](repeating: 0, count: 5*Int(min(m.pointee, n.pointee)))
                return cgesvd_(jobu, jobvt, m, n, recast(a), lda, recast(s), recast(u), ldu, recast(vt), ldvt, recast(work), lwork, &rwork, info)
            },
            double: {
                var rwork = [Double](repeating: 0, count: 5*Int(min(m.pointee, n.pointee)))
                return zgesvd_(jobu, jobvt, m, n, recast(a), lda, recast(s), recast(u), ldu, recast(vt), ldvt, recast(work), lwork, &rwork, info)
            }
        )
    }
    
    public static func lapack_heev(_ jobz : UnsafeMutablePointer<Int8>, _ uplo : UnsafeMutablePointer<Int8>, _ n : UnsafeMutablePointer<IntLA>,
                                   _ a : UnsafeMutablePointer<Self>, _ lda : UnsafeMutablePointer<IntLA>,
                                   _ w : UnsafeMutablePointer<Self.Magnitude>,
                                   _ work : UnsafeMutablePointer<Self>, _ lwork : UnsafeMutablePointer<IntLA>,
                                   _ info : UnsafeMutablePointer<IntLA>) -> Int32
    {
        var rwork : [Self.Magnitude] = Array(repeating: 0, count: max(1, 3*Int(n.pointee)-2))
        return dispatch(
            float: { cheev_(jobz, uplo, n, recast(a), lda, recast(w), recast(work), lwork, recast(&rwork), info) },
            double: { zheev_(jobz, uplo, n, recast(a), lda, recast(w), recast(work), lwork, recast(&rwork), info) }
        )
    }
    
    public static func lapack_gees(_ jobvs : UnsafeMutablePointer<Int8>, _ n : UnsafeMutablePointer<IntLA>,
                                   _ a : UnsafeMutablePointer<Self>, _ lda : UnsafeMutablePointer<IntLA>,
                                   _ wr : UnsafeMutablePointer<Self.Magnitude>,
                                   _ wi : UnsafeMutablePointer<Self.Magnitude>,
                                   _ vs : UnsafeMutablePointer<Self>, _ ldvs : UnsafeMutablePointer<IntLA>,
                                   _ work : UnsafeMutablePointer<Self>, _ lwork : UnsafeMutablePointer<IntLA>,
                                   _ info : UnsafeMutablePointer<IntLA>) -> Int32
    {
        let N = Int(n.pointee)
        var rwork : [Self.Magnitude] = Array(repeating: 0, count: N)
        var sort : Int8 = 0x4E /* "N" */
        var sdim : IntLA = 0
        var w : [Self] = Array(repeating: 0, count: N)
        let result = dispatch(
            float: { cgees_(jobvs, &sort, nil, n, recast(a), lda , &sdim, recast(&w), recast(vs), ldvs, recast(work), lwork, recast(&rwork), nil, info) },
            double: { zgees_(jobvs, &sort, nil, n, recast(a), lda , &sdim, recast(&w), recast(vs), ldvs, recast(work), lwork, recast(&rwork), nil, info) }
        )
        for i in 0 ..< N {
            wr[i] = w[i].real
            wi[i] = w[i].imaginary
        }
        return result
    }
    
    public static func vDSP_convert(interleavedComplex : [Self]) -> (real: [Self.Magnitude], imaginary: [Self.Magnitude]) {
        let N = vDSP_Length(interleavedComplex.count)
        var real: [Self.Magnitude] = Array(repeating: 0, count: Int(N))
        var imaginary: [Self.Magnitude] = Array(repeating: 0, count: Int(N))
        dispatch(
            float: {
                var split = DSPSplitComplex(realp: recast(&real), imagp: recast(&imaginary))
                vDSP_ctoz(recast(interleavedComplex), 2, &split, 1, N)
            },
            double: {
                var split = DSPDoubleSplitComplex(realp: recast(&real), imagp: recast(&imaginary))
                vDSP_ctozD(recast(interleavedComplex), 2, &split, 1, N)
            }
        )
        return (real: real, imaginary: imaginary)
    }
    
    public static func vDSP_convert(real: [Self.Magnitude], imaginary: [Self.Magnitude]) -> [Self] {
        precondition(real.count == imaginary.count)
        let N = vDSP_Length(real.count)
        var result : [Self] = Array(repeating: 0, count: Int(N))
        dispatch(
            float: {
                var real = real
                var imaginary = imaginary
                var split = DSPSplitComplex(realp: recast(&real), imagp: recast(&imaginary))
                vDSP_ztoc(&split, 1, recast(&result), 2, N)
            },
            double: {
                var real = real
                var imaginary = imaginary
                var split = DSPDoubleSplitComplex(realp: recast(&real), imagp: recast(&imaginary))
                vDSP_ztocD(&split, 1, recast(&result), 2, N)
            }
        )
        return result
    }
    
    public static func vDSP_elementwise_absolute(_ v : [Self]) -> [Self.Magnitude] {
        var (real, imaginary) = vDSP_convert(interleavedComplex: v)
        let N = vDSP_Length(v.count)
        var result: [Self.Magnitude] = Array(repeating: 0, count: Int(N))
        dispatch (
            float: {
                var split = DSPSplitComplex(realp: recast(&real), imagp: recast(&imaginary))
                vDSP_zvabs(&split, 1, recast(&result), 1, N)
            },
            double: {
                var split = DSPDoubleSplitComplex(realp: recast(&real), imagp: recast(&imaginary))
                vDSP_zvabsD(&split, 1, recast(&result), 1, N)
            }
        )
        return result
    }
    
    public static func vDSP_elementwise_adjoint(_ v : [Self]) -> [Self] {
        var (real, imaginary) = vDSP_convert(interleavedComplex: v)
        let N = vDSP_Length(v.count)
        var target_real : [Self.Magnitude] = Array(repeating: 0, count: Int(N))
        var target_imaginary : [Self.Magnitude] = Array(repeating: 0, count: Int(N))
        dispatch(
            float: {
                var source_split = DSPSplitComplex(realp: recast(&real), imagp: recast(&imaginary))
                var target_split = DSPSplitComplex(realp: recast(&target_real), imagp: recast(&target_imaginary))
                vDSP_zvconj(&source_split, 1, &target_split, 1, N)
            },
            double: {
                var source_split = DSPDoubleSplitComplex(realp: recast(&real), imagp: recast(&imaginary))
                var target_split = DSPDoubleSplitComplex(realp: recast(&target_real), imagp: recast(&target_imaginary))
                vDSP_zvconjD(&source_split, 1, &target_split, 1, N)
            }
        )
        return vDSP_convert(real: target_real, imaginary: target_imaginary)
    }
        
    public static func vDSP_elementwise_multiply(_ u : [Self], _ v : [Self]) -> [Self] {
        let N = u.count
        precondition(N == v.count)
        var (real_u, imaginary_u) = vDSP_convert(interleavedComplex: u)
        var (real_v, imaginary_v) = vDSP_convert(interleavedComplex: v)
        var target_real : [Self.Magnitude] = Array(repeating: 0, count: N)
        var target_imaginary : [Self.Magnitude] = Array(repeating: 0, count: N)
        dispatch(
            float: {
                var split_u = DSPSplitComplex(realp: recast(&real_u), imagp: recast(&imaginary_u))
                var split_v = DSPSplitComplex(realp: recast(&real_v), imagp: recast(&imaginary_v))
                var target_split = DSPSplitComplex(realp: recast(&target_real), imagp: recast(&target_imaginary))
                vDSP_zvmul(&split_u, 1, &split_v, 1, &target_split, 1, vDSP_Length(N), 1)
            },
            double: {
                var split_u = DSPDoubleSplitComplex(realp: recast(&real_u), imagp: recast(&imaginary_u))
                var split_v = DSPDoubleSplitComplex(realp: recast(&real_v), imagp: recast(&imaginary_v))
                var target_split = DSPDoubleSplitComplex(realp: recast(&target_real), imagp: recast(&target_imaginary))
                vDSP_zvmulD(&split_u, 1, &split_v, 1, &target_split, 1, vDSP_Length(N), 1)
            }
        )
        return vDSP_convert(real: target_real, imaginary: target_imaginary)
    }
    
    public static func vDSP_elementwise_divide(_ u : [Self], _ v : [Self]) -> [Self] {
        let N = u.count
        precondition(N == v.count)
        var (real_u, imaginary_u) = vDSP_convert(interleavedComplex: u)
        var (real_v, imaginary_v) = vDSP_convert(interleavedComplex: v)
        var target_real : [Self.Magnitude] = Array(repeating: 0, count: N)
        var target_imaginary : [Self.Magnitude] = Array(repeating: 0, count: N)
        dispatch(
            float: {
                var split_u = DSPSplitComplex(realp: recast(&real_u), imagp: recast(&imaginary_u))
                var split_v = DSPSplitComplex(realp: recast(&real_v), imagp: recast(&imaginary_v))
                var target_split = DSPSplitComplex(realp: recast(&target_real), imagp: recast(&target_imaginary))
                vDSP_zvdiv(&split_v, 1, &split_u, 1, &target_split, 1, vDSP_Length(N))
            },
            double: {
                var split_u = DSPDoubleSplitComplex(realp: recast(&real_u), imagp: recast(&imaginary_u))
                var split_v = DSPDoubleSplitComplex(realp: recast(&real_v), imagp: recast(&imaginary_v))
                var target_split = DSPDoubleSplitComplex(realp: recast(&target_real), imagp: recast(&target_imaginary))
                vDSP_zvdivD(&split_v, 1, &split_u, 1, &target_split, 1, vDSP_Length(N))
            }
        )
        return vDSP_convert(real: target_real, imaginary: target_imaginary)
    }

}

