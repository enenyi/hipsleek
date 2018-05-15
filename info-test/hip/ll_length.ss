data node {
  int v;
  node n;
}

pred pub_ll<n> == self=null & n=0 & self<?@Lo
  or self::node<v,q> * q::pub_ll<m> & n>0 & m=n-1 & self<?@Lo & v<?@Lo
  inv n>=0;
pred pri_ll<n> == self=null & n=0 & self<?@Hi
  or self::node<v,q> * q::pri_ll<m> & n>0 & m=n-1 & self<?@Hi & v<?@Hi
  inv n>=0;

lemma_safe "public->private" self::pub_ll<n> -> self::pri_ll<n>;
lemma_safe "private->public_fail" self::pri_ll<n> -> self::pub_ll<n>;

int length1(node p)
  requires p::pub_ll<n> & p <? @Lo
  ensures res=n & res <? @Lo;
{
  if(p == null) {
    return 0;
  } else {
    return 1 + length1(p.n);
  }
}

int length2(node p)
  requires p::pub_ll<n> & p <? @Lo
  ensures res=n & res <? @Hi;
{
  if(p == null) {
    return 0;
  } else {
    return 1 + length2(p.n);
  }
}

int length3_fail(node p)
  requires p::pri_ll<n> & p <? @Hi
  ensures res=n & res <? @Lo;
{
  if(p == null) {
    return 0;
  } else {
    return 1 + length3_fail(p.n);
  }
}

int length4(node p)
  requires p::pri_ll<n> & p <? @Hi
  ensures res=n & res <? @Hi;
{
  if(p == null) {
    return 0;
  } else {
    return 1 + length4(p.n);
  }
}