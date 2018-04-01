void upd_arr(arrI base, int i, int v)
   requires base::Elem<i,_> & i>=0
   ensures base::Elem<i,v>;


int read_arr(arrI base, int i)
   requires base::Elem<i,_> & i>=0
   ensures base::Elem<i,v> & res=v;

/*
void upd_arr(arrI base, int i, int v)
   requires base::AsegNE<i,i+1> & i>=0
   ensures base::AsegNE<i,i+1>;

int read_arr(arrI base, int i)
   requires base::AsegNE<i,i+1> & i>=0
   ensures base::AsegNE<i,i+1>;
*/


// Should succeed
int select(arrI base,int i,int m)
  requires base::AsegNE<i,m> & i>=0
  ensures base::AsegNE<i,m> & res>=i & res<m; 
{

 if(i+1<m){
    int tmpi = select(base,i+1,m);
	int tmp1,tmp2;
	tmp1 = read_arr(base,tmpi);
	tmp2 = read_arr(base,i);
	if(tmp1<tmp2){
	   //assume false;
	   return i;
		  }
	else{
	   //assume false;
	   return tmpi;
       }
     }
   else{
	//assume false;
	return i;
   }
}

/*
void bubble_sort(arrI base, int i, int m)
  requires base::AsegNE<i,m> & i>=0
  ensures base::AsegNE<i,m>;
{
 if(i+1<m){
	 bubble_push(base,i,m);
	 bubble_sort(base,i+1,m);
 }
   }
*/
