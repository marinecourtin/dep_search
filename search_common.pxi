from libcpp cimport bool
from db_util cimport DB
from setlib.pytset cimport PyTSet, PyTSetArray
from libc.stdlib cimport malloc
from libc.stdint cimport uint32_t

cdef extern from "tset.h" namespace "tset":
    cdef cppclass TSet:
        int tree_length
        int array_len
        TSet(int) except +
        void intersection_update(TSet *)
        void minus_update(TSet *)
        void union_update(TSet *)
        void add_item(int)
        bool has_item(int)
        void fill_ones()
        bool is_empty()
        void print_set()
        void erase()
        void set_length(int tree_length)
        void complement()
        void copy(TSet *other)

    cdef cppclass TSetArray:
        int tree_length
        int array_len
        TSetArray(int length) except +
        void intersection_update(TSetArray *other)
        void union_update(TSetArray *other)
        void erase()
        void get_set(int index, TSet *result)
        void deserialize(const void *data, int size)
        void print_array()
        void erase()
        void set_length(int tree_length)
        void copy(TSetArray *other)

cdef extern from "query_functions.h":
    void pairing(TSet *index_set, TSet *other_set, TSetArray *mapping, bool negated)


# This is query object in query.py
cdef class Search:  # base class for all searches
    cdef void **sets  #Pointers to stuff coming from the DB: array 1 and set 2 (we don't need 0)
    cdef int *set_types
    cdef set_size
    cdef int ops
    cdef bool started

    cdef uint32_t *set_ids
    cdef unsigned char* types
    cdef unsigned char *optional

    #Declared here, overridden in the generated query code
    cdef TSet *exec_search(self):
        pass

    cdef void initialize(self):
        pass
    #End of overriden declarations
    
    def set_db_options(self, p_set_ids, p_types, p_optional):

        cdef uint32_t *set_ids = <uint32_t *>malloc(len(p_set_ids) * sizeof(uint32_t))
        for i, s in enumerate(p_set_ids):
            set_ids[i] = s
        self.set_ids = set_ids

        cdef unsigned char *types = <unsigned char *>malloc(len(p_set_ids) * sizeof(unsigned char))
        self.types = types
        print "<types>"
        for i, s in enumerate(p_types):
            if s:
                types[i] = <char>2
                print i, s, 2
            else:
                types[i] = <char>1
                print i, s, 1
        print "</types>"

        cdef unsigned char *optional = <unsigned char *>malloc(len(p_optional) * sizeof(unsigned char))
        for i, s in enumerate(p_optional):
            if s:
                optional[i] = <char>1
            else:
                optional[i] = <char>0
        self.optional = optional

        self.set_size = len(p_set_ids)
        self.started = False


    def next_result(self, DB db):
        cdef int size=len(self.query_fields)
        cdef PyTSet py_result=PyTSet(0)
        cdef TSet *result
        cdef int graph_id
        cdef int rows=0
        cdef uint32_t * tree_id

        err=db.get_next_fitting_tree()
        if err or db.finished():
            return -1

        self.initialize()
        db.fill_sets(self.sets, self.set_ids, <unsigned char *>self.types, self.optional, self.set_size)
        result=self.exec_search()

        result_set = set()
        #Really + 1 ?
        for x in range(result.tree_length + 1):
            if result.has_item(x):
                result_set.add(x)

        return result_set


    # def x_next_result(self, DB db):
    #     cdef int size=len(self.query_fields)
    #     cdef PyTSet py_result=PyTSet(0)
    #     cdef TSet *result
    #     cdef int graph_id
    #     cdef int rows=0
    #     while db.next()==0:
    #         rows+=1
    #         graph_id=db.get_integer(0)
    #         #db.fill_sets(self.sets,self.set_types,size)
    #         self.initialize()
    #         result=self.exec_search()
    #         if not result.is_empty():
    #             py_result.acquire_thisptr(result)
    #             return graph_id,py_result,rows

    #     return None,None,rows
