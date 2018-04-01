int read_ptr(arrI ptr)
   requires base::Elem<i,v> & ptr = base + i
   ensures base::Elem<i,v> & res = v;

void upd_arr(arrI ptr, int v)
   requires base::Elem<i,_> & ptr = base + i
   ensures base::Elem<i,v>;

arrI ptr_add(arrI ptr, int index)
   requires ptr!=null
   ensures res = ptr + index;



arrI alloc(int length)
   requires emp & length>0
   ensures base::AsegNE<0, length> & res = base & base!=null;

int main(){
	   arrI ptr = alloc(10);

	   arrI tmp_ptr = ptr_add(ptr, 5);

	   read_ptr(tmp_ptr);
	   return 0;
}
