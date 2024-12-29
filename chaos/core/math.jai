// TODO: can we ditch this and do everything ourselves? It should be easy to write a couple helpers +limits ourselves
#import "Math";
#import "Bit_Operations";
/*
  * This is the math layer for the whole engine.
  * We use the GLTF coordinate system (rhs), our <right,up,frw> vectors are:
  * - World Space <-x,+y,+z> (think about smiley face in front of camera)
  * - Camera Space <+x,+y,-z> (we are facing the negative-z axis)
  * )
  * For some good resources on GameDev math I recommend:
  * https://www.scratchapixel.com/index.html
  * https://learnopengl.com/
  * https://immersivemath.com/ila/index.html
  * TODO: we need to add support for Quaternions
*/

////////////////////////
// Vectors
////////////////////////

v2:: struct {
  x,y : float;
  #place x; r,g : float;
  #place x; arr : [2]float;
}
operator [] :: (v: v2, i : int) -> float {return v.arr[i];}
operator []= :: (v: *v2, i : int, item: float) {v.arr[i] = item;}
operator *[] :: (v: *v2, i : int) -> *v2 {return *v.arr[i];}
operator *= :: (v: *v2, scalar : float) {v.x *= scalar;v.y*=scalar;}
operator + :: (v: v2, scalar : float) -> v2 {return .{v.x+scalar,v.y+scalar};}
operator - :: (v: v2, scalar : float) -> v2 {return .{v.x-scalar,v.y-scalar};}
operator * :: (v: v2, scalar : float) -> v2 {return .{v.x*scalar,v.y*scalar};}
operator / :: (v: v2, scalar : float) -> v2 {return .{v.x/scalar,v.y/scalar};}
operator + :: (a: v2, b : v2) -> v2 {return .{a.x+b.x,a.y+b.y};}
operator - :: (a: v2, b : v2) -> v2 {return .{a.x-b.x,a.y-b.y};}
operator * :: (a: v2, b : v2) -> v2 {return .{a.x*b.x,a.y*b.y};}
operator / :: (a: v2, b : v2) -> v2 {return .{a.x/b.x,a.y/b.y};}
v2_dot :: (a : v2, b : v2) -> float {return a.x*b.x+a.y*b.y;}
v2_len :: (v : v2) -> float { return sqrt(v2_dot(v,v));}
v2_norm :: (v : v2) -> v2 {return v*(1.0/v2_len(v));}

v3:: struct {
  x,y,z : float;
  #place x; r,g,b : float;
  #place x; arr : [3]float;
}
operator [] :: (v: v3, i : int) -> float {return v.arr[i];}
operator []= :: (v: *v3, i : int, item: float) {v.arr[i] = item;}
operator *[] :: (v: *v3, i : int) -> *v3 {return *v.arr[i];}
operator *= :: (v: *v3, scalar : float) {v.x *= scalar;v.y*=scalar;v.z*=scalar;}
operator + :: (v: v3, scalar : float) -> v3 {return .{v.x+scalar,v.y+scalar,v.z+scalar};}
operator - :: (v: v3, scalar : float) -> v3 {return .{v.x-scalar,v.y-scalar,v.z-scalar};}
operator * :: (v: v3, scalar : float) -> v3 {return .{v.x*scalar,v.y*scalar,v.z*scalar};}
operator / :: (v: v3, scalar : float) -> v3 {return .{v.x/scalar,v.y/scalar,v.z/scalar};}
operator + :: (a: v3, b : v3) -> v3 {return .{a.x+b.x,a.y+b.y,a.z+b.z};}
operator - :: (a: v3, b : v3) -> v3 {return .{a.x-b.x,a.y-b.y,a.z-b.z};}
operator * :: (a: v3, b : v3) -> v3 {return .{a.x*b.x,a.y*b.y,a.z*b.z};}
operator / :: (a: v3, b : v3) -> v3 {return .{a.x/b.x,a.y/b.y,a.z/b.z};}
v3_dot :: (a : v3, b : v3) -> float {return a.x*b.x+a.y*b.y+a.z*b.z;}
v3_len :: (v : v3) -> float { return sqrt(v3_dot(v,v));}
v3_norm :: (v : v3) -> v3 {return v*(1.0/v3_len(v));}
v3_cross :: (lhs : v3, rhs : v3) -> v3 {return v3.{lhs.y*rhs.z - lhs.z*rhs.y, lhs.z*rhs.x - lhs.x*rhs.z, lhs.x*rhs.y - lhs.y*rhs.x};}

// NOTE: cross product is right-handed, meaning for vectors A and B the vector produced will be
// your thumb if your index is A, and your middle is B, for example:
// for example here, A = .{1,0,0}, B = .{0,1,0} and cross product C = .{0,0,1}
#run {
  res := v3_cross(.{1,0,0}, .{0,1,0});
  expected := v3.{0,0,1};
  assert(bits_equal(*res,*expected));
}

v4:: struct {
  x,y,z,w : float;
  #place x; r,g,b,a : float;
  #place z; width,height : float; // NOTE: we have this for viewports.. should we?
  #place x; arr : [4]float;
}
operator [] :: (v: v4, i : int) -> float {return v.arr[i];}
operator []= :: (v: *v4, i : int, item: float) {v.arr[i] = item;}
operator *[] :: (v: *v4, i : int) -> *v4 {return *v.arr[i];}
operator *= :: (v: *v4, scalar : float) {v.x *= scalar;v.y*=scalar;v.z*=scalar;v.w*=scalar;}
operator + :: (v: v4, scalar : float) -> v4 {return .{v.x+scalar,v.y+scalar,v.z+scalar,v.w+scalar};}
operator - :: (v: v4, scalar : float) -> v4 {return .{v.x-scalar,v.y-scalar,v.z-scalar,v.w-scalar};}
operator * :: (v: v4, scalar : float) -> v4 {return .{v.x*scalar,v.y*scalar,v.z*scalar,v.w*scalar};}
operator / :: (v: v4, scalar : float) -> v4 {return .{v.x/scalar,v.y/scalar,v.z/scalar,v.w/scalar};}
operator + :: (a: v4, b : v4) -> v4 {return .{a.x+b.x,a.y+b.y,a.z+b.z,a.w+b.w};}
operator - :: (a: v4, b : v4) -> v4 {return .{a.x-b.x,a.y-b.y,a.z-b.z,a.w-b.w};}
operator * :: (a: v4, b : v4) -> v4 {return .{a.x*b.x,a.y*b.y,a.z*b.z,a.w*b.w};}
operator / :: (a: v4, b : v4) -> v4 {return .{a.x/b.x,a.y/b.y,a.z/b.z,a.w/b.w};}
v4_dot :: (a : v4, b : v4) -> float {return a.x*b.x+a.y*b.y+a.z*b.z+a.w*b.w;}
v4_len :: (v : v4) -> float { return sqrt(v4_dot(v,v));}
v4_norm :: (v : v4) -> v4 {return v*(1.0/v4_len(v));}

iv4:: struct {
  x,y,z,w : u32;
  #place x; r,g,b,a : u32;
  #place x; arr : [4]u32;
}

////////////////////////
// Matrices
////////////////////////

// NOTE: Object Space --Mwrld--> World Space --Mview--> View Space (-z fwd, rhs) --Mproj--> Clip Space --persp_div--> NDC Space [-1,1] --viewport--> Screen Space [ww,wh]

/*
* Sigh
* */

/* Matrix storage 
* To visualize the matrix better, as is shown below we are storing the matrix
* row-by-row but because I like the notation better, we post-multiply (M2*M1*P) in our calculations
* maybe this should change for clarity but I don't see any reason to. @Check
* SIDENOTE: to have row-major storage in OpenGL we pass the Transpose=true property to needed OpenGL calls currently.
* */

m4 :: struct {
  _11, _12, _13, _14 : float;
  _21, _22, _23, _24 : float;
  _31, _32, _33, _34 : float;
  _41, _42, _43, _44 : float;

  #place _11; v:    [4] v4; // row vectors (for correct OpenGL storage right?)
  #place _11; coef: [4][4] float;
  #place _11; raw:  [16]   float;
}

m4_I :: m4.{_11 = 1, _22 = 1, _33 = 1, _44 = 1};

row :: (m: m4, i: int) -> v4 {
  return m.v[i];
}

column :: (m: m4, i: int) -> v4 {
    return .{m.coef[0][i], m.coef[1][i], m.coef[2][i], m.coef[3][i]};
}

m4_trans :: (v : v3) -> m4 {
  t : m4 = m4_I;
  t._14 = v.x;
  t._24 = v.y;
  t._34 = v.z;
  return t;
}

m4_scale :: (v : v3) -> m4 {
  s : m4 = m4_I;
  for i : 0..2 {
    s.coef[i][i] = v[i];
  }
  return s;
}

// This is SUPER slow, @FIX
m4_mult :: (a: m4, b: m4) -> m4{
  res : m4 = ---;
  for r : 0..3 {
    for c : 0..3 {
      res.coef[r][c] = v4_dot(row(a,r), column(b,c)); 
    }
  }
  return res;
}

m4_multv :: (a : m4, v : v4) -> v4 {
  res : v4 = ---;
  for i : 0..3 {
    res[i] = v4_dot(row(a,i), v);
  }
  return res;
}

// NOTE: We do post-multiplication, meaning mults are done in right towards left order
// Like below, translating -> scaling != scaling -> translating
// TODO: Add * operators so we are not in this function hell
#run {
  a := m4_scale(.{0.5,0.5,0.5});
  b := m4_trans(.{1,0,0});

  v1 := m4_multv(m4_mult(a,b), v4.{1,0,0,1}); // first trans then scale -> (1,0,0) -T-> (2,0,0) -S-> (1,0,0)
  expected1 := v4.{1,0,0,1};
  assert(bits_equal(*v1,*expected1));

  v2 := m4_multv(m4_mult(b,a), v4.{1,0,0,1}); // first scale then trans -> (1,0,0) -S-> (0.5,0,0) -T-> (1.5,0,0)
  expected2 := v4.{1.5,0,0,1};
  assert(bits_equal(*v2,*expected2));
}

m4_transpose :: (m: m4) -> m4 {
    trans : m4;
    for i: 0..3  {
      for j: 0..3 {
          trans.coef[i][j] = m.coef[j][i];
      }
    }
    return trans;
}

m4_inverse :: (m: m4, epsilon := 0.0001) -> m4, bool {
  a := v3.{m._11, m._21, m._31};
  b := v3.{m._12, m._22, m._32};
  c := v3.{m._13, m._23, m._33};
  d := v3.{m._14, m._24, m._34};

  x := m._41;
  y := m._42;
  z := m._43;
  w := m._44;

  s := v3_cross(a, b);
  t := v3_cross(c, d);
  u := a * y - b * x;
  v := c * w - d * z;

  det := v3_dot(s, v) + v3_dot(t, u);
  inv_det := 1.0 / det;
  s *= inv_det;
  t *= inv_det;
  u *= inv_det;
  v *= inv_det;

  r0 := v3_cross(b, v) + t * y;
  r1 := v3_cross(v, a) - t * x;
  r2 := v3_cross(d, u) + s * w;
  r3 := v3_cross(u, c) - s * z;

  return .{
    r0.x, r0.y, r0.z, -v3_dot(b, t),
    r1.x, r1.y, r1.z,  v3_dot(a, t),
    r2.x, r2.y, r2.z, -v3_dot(d, s),
    r3.x, r3.y, r3.z,  v3_dot(c, s)},
  abs(det) < epsilon;
}

//@NOTE: We can see here that M * M^-1 = I, as it SHOULD
#run {
  test := m4_scale(.{0.5,0.5,0.5});
  mult := m4_mult(test, m4_inverse(test));
  expected := m4_I;
  assert(bits_equal(*mult,*expected));
  mult = m4_mult(m4_inverse(test), test);
  assert(bits_equal(*mult,*expected));
}

rad_to_deg :: (d : float) -> float {
  RAD2DEG :: #run (180.0/acos(-1.0));
  return RAD2DEG * d;
}

deg_to_rad :: (d : float) -> float {
  DEG2RAD :: #run (acos(-1.0) / 180.0);
  return DEG2RAD * d;
}

m4_persp :: (fovX : float32, aspect_ratio : float32, front : float, back : float32) -> m4 {
  tangent := tan(deg_to_rad(fovX/2));
  right := front * tangent;
  top := right / aspect_ratio;

  m : m4 = m4_I;
  m._11  =  front / right;
  m._22  =  front / top;
  m._33 = -(back + front) / (back - front);
  m._34 = -(2 * back * front) / (back - front);
  m._43 = -1.0;
  m._44 =  0.0;
  return m;
}

//////////////////////////////////////////
// Perspective matrix specifics extraction
//////////////////////////////////////////
persp_get_near :: (pm : m4) -> float32 { return pm._34 / (pm._33 -1); }
persp_get_far :: (pm : m4) -> float32 { n := persp_get_near(pm); return n*(pm._33-1)/(pm._33+1); }

persp_get_aspect_ratio :: (pm : m4) -> float32 {
  front := persp_get_near(pm);
  right := (1.0/pm._11) * front;
  top := (1.0/pm._22) * front;
  return (1.0/top)*right;
}
persp_get_fovx :: (pm : m4) -> float32 {
  front := persp_get_near(pm);
  right := (1.0/pm._11) * front;
  tangent := right / front; 
  return 2 * rad_to_deg(atan(tangent));
}

// TODO: can we NOT have a max cascades maybe? possible dynamic allocation though
MAX_CASCADES :: 4;
m4_persp_gen_cascades :: (pm : m4, cascades_count : u32) -> [MAX_CASCADES]m4 {
  pm_near := persp_get_near(pm);
  pm_far := persp_get_far(pm);
  pm_aspect := persp_get_aspect_ratio(pm);
  pm_fovx := persp_get_fovx(pm);
  assert(cascades_count > 0 && cascades_count <= MAX_CASCADES);
  cascades : [MAX_CASCADES]m4;
  for i : 0..cascades_count-1 {
    step := (pm_far - pm_near) / cascades_count;
    near := pm_near + i * step;
    far := pm_near + (i+1) * step;
    cascades[i] = m4_persp(pm_fovx, pm_aspect, near, far);
  }
  return cascades;
}
////////////////////////////////////////////

m4_ortho :: (l : float32, r : float32, b : float32, t : float32, n : float32, f : float32) -> m4 {
  m : m4 = m4_I;
  m._11  = 2 / (r - l);
  m._22  = 2 / (t - b);
  m._33 = -2 / (f - n);
  m._14 = -(r + l) / (r - l);
  m._24 = -(t + b) / (t - b);
  m._34 = -(f + n) / (f - n);
  m._44 = 1.0;
  return m;
}


// @NOTE: eye is camera position, center is where its looking at, dummy up is {0,1,0}
m4_look_at :: (eye: v3, center : v3, dummy_up : v3) -> m4 {
  m4_look_at_FRU :: (F: v3, R : v3, U : v3, eye : v3) -> m4 {
    res : m4;

    res.coef[0][0] = R.x;
    res.coef[0][1] = U.x;
    res.coef[0][2] = -F.x;
    res.coef[0][3] = 0.0;

    res.coef[1][0] = R.y;
    res.coef[1][1] = U.y;
    res.coef[1][2] = -F.y;
    res.coef[1][3] = 0.0;

    res.coef[2][0] = R.z;
    res.coef[2][1] = U.z;
    res.coef[2][2] = -F.z;
    res.coef[2][3] = 0.0;

    res.coef[3][0] = -v3_dot(R, eye);
    res.coef[3][1] = -v3_dot(U, eye);
    res.coef[3][2] = v3_dot(F, eye);
    res.coef[3][3] = 1.0;

    return m4_transpose(res);
  }
  mat := m4_I;

  F := v3_norm(center - eye);
  R := v3_norm(v3_cross(F, dummy_up));
  U := v3_norm(v3_cross(R, F));
  return m4_look_at_FRU(F,R,U, eye);
}

m4_rotate :: (angle : float, axis : v3) -> m4 {
  using axis;
  m : m4 = m4_I;
  c := cos(angle);
  s := sin(angle);
  one_minus_c := 1.0 - c;

  m._11 = c + x * x * one_minus_c;
  m._21 = x * y * one_minus_c - z * s;
  m._31 = x * z * one_minus_c + y * s;

  m._12 = y * x * one_minus_c + z * s;
  m._22 = c + y * y * one_minus_c;
  m._32 = y * z * one_minus_c - x * s;

  m._13 = z * x * one_minus_c - y * s;
  m._23 = z * y * one_minus_c + x * s;
  m._33 = c + z * z * one_minus_c;

  return m;
}

////////////////////////
// Quaternions (TBA)
////////////////////////


Quat :: struct {
  x,y,z,w : float;
};
quat_I :: Quat.{1.0,0.0,0.0,0.0};
