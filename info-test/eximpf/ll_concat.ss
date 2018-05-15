data node {
  int v;
  node n;
}

pred pub_ll<n> == self=null & n=0 & self <E @Lo
  or self::node<v,q> * q::pub_ll<m> & n>0 & m=n-1 & self <E @Lo & v <E @Lo
  inv n>=0;
pred pri_ll<n> == self=null & n=0 & self <E @Hi
  or self::node<v,q> * q::pri_ll<m> & n>0 & m=n-1 & self <E @Hi & v <E @Hi
  inv n>=0;

lemma_safe "public->private" self::pub_ll<n> -> self::pri_ll<n>;
lemma_safe "private->public_fail" self::pri_ll<n> -> self::pub_ll<n>;

node concat1(node p, node q)
  requires p::pub_ll<n> * q::pub_ll<m> & p  <E  @Lo & q  <E  @Lo
  ensures res::pub_ll<n+m> & res <E @Lo;
{
  if(p == null) {
    return q;
  } else {
    p.n = concat1(p.n, q);
    return p;
  }
}

node concat2(node p, node q)
  requires p::pub_ll<n> * q::pub_ll<m> & p  <E  @Lo & q  <E  @Lo
  ensures res::pri_ll<n+m> & res <E @Hi;
{
  if(p == null) {
    return q;
  } else {
    p.n = concat2(p.n, q);
    return p;
  }
}

node concat3_fail(node p, node q)
  requires p::pub_ll<n> * q::pri_ll<m> & p  <E  @Lo & q  <E  @Hi
  ensures res::pub_ll<n+m> & res <E @Lo;
{
  if(p == null) {
    return q;
  } else {
    p.n = concat3_fail(p.n, q);
    return p;
  }
}

node concat4(node p, node q)
  requires p::pub_ll<n> * q::pri_ll<m> & p  <E  @Lo & q  <E  @Hi
  ensures res::pri_ll<n+m> & res <E @Hi;
{
  if(p == null) {
    return q;
  } else {
    p.n = concat4(p.n, q);
    return p;
  }
}

node concat5_fail(node p, node q)
  requires p::pri_ll<n> * q::pub_ll<m> & p  <E  @Hi & q  <E  @Lo
  ensures res::pub_ll<n+m> & res <E @Lo;
{
  if(p == null) {
    return q;
  } else {
    p.n = concat5_fail(p.n, q);
    return p;
  }
}

node concat6(node p, node q)
  requires p::pri_ll<n> * q::pub_ll<m> & p  <E  @Hi & q  <E  @Lo
  ensures res::pri_ll<n+m> & res <E @Hi;
{
  if(p == null) {
    return q;
  } else {
    p.n = concat6(p.n, q);
    return p;
  }
}

node concat7_fail(node p, node q)
  requires p::pri_ll<n> * q::pri_ll<m> & p  <E  @Hi & q  <E  @Hi
  ensures res::pub_ll<n+m> & res <E @Lo;
{
  if(p == null) {
    return q;
  } else {
    p.n = concat7_fail(p.n, q);
    return p;
  }
}

node concat8(node p, node q)
  requires p::pri_ll<n> * q::pri_ll<m> & p  <E  @Hi & q  <E  @Hi
  ensures res::pri_ll<n+m> & res <E @Hi;
{
  if(p == null) {
    return q;
  } else {
    p.n = concat8(p.n, q);
    return p;
  }
}