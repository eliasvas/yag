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

