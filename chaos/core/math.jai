// TODO: can we ditch this and do everything ourselves? It should be easy to write a couple helpers +limits ourselves
#import "Math";
#import "Bit_Operations";
/*
* This is the math layer for the whole engine.
* We use the GLTF coordinate system (rhs), our <right,up,frw> vectors are:
* - World Space <-x,+y,+z> (think about smiley face in front of camera)
* - Camera Space <+x,+y,-z> (we are facing the negative-z axis)
* - we use row-major vector storage because we arent stupid.
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

////////////////////////
// Matrices
////////////////////////

// NOTE: Object Space --Mwrld--> World Space --Mview--> View Space (-z fwd, rhs) --Mproj--> Clip Space --persp_div--> NDC Space [-1,1] --viewport--> Screen Space [ww,wh]

/*
* Sigh
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


////////////////////////
// Quaternions (TBA)
////////////////////////


