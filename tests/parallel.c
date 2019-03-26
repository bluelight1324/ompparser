//For testing purpose, there are several extra empty lines.
//The final version should only contain necessary information.
//This is not a C/C++ code, so there's no required writing style.
//Only two kinds of special lines will be recognized.
  //One is starting with "omp", which is the input.
//The other one is starting with "PASS: ", which is the result for validation.

#pragma omp parallel private (a[foo(x, goo(x, y)):100], b[1:30], c)
PASS: #pragma omp parallel private (a[foo(x, goo(x, y)):100], b[1:30], c)

!$OMP PARALLEL PRIVATE(a, b)
PASS: !$omp parallel private(a, b)
  
#paragma omp parallel privete
PASS: privete is not a valid keyword
  
#pragma omp parallel num_threads (3*5+4/(7+10))
PASS: #pragma omp parallel num_threads (3*5+4/(7+10))

#pragma omp parallel firstprivate (foo(x), y)
PASS: #pragma omp parallel firstprivate (foo(x), y)


#pragma omp parallel shared (a, b, c[1:10])

PASS: #pragma omp parallel shared (a, b, c[1:10])

#pragma omp parallel copyin (a[foo(goo(x)):20],a,y)
PASS: #pragma omp parallel copyin (a[foo(goo(x)):20], a, y)

#pragma omp parallel default (shared)
PASS: #pragma omp parallel default (shared)

#pragma omp parallel default (none)
PASS: #pragma omp parallel default (none)

#pragma omp parallel if (a) if (parallel : b) default (firstprivate)
PASS: #pragma omp parallel if (a) if (parallel: b) default (firstprivate)

#pragma omp parallel proc_bind (master)
PASS: #pragma omp parallel proc_bind (master)

#pragma omp parallel proc_bind (close) default (private)
PASS: #pragma omp parallel default (private) proc_bind (close)

#pragma omp parallel proc_bind (spread)
PASS: #pragma omp parallel proc_bind (spread)

#pragma omp parallel reduction (inscan, + : a, foo(x)) reduction (abc : x, y, z) reduction (task, user_defined_value : x, y, z) reduction (inscan, max : a, foo(x))
PASS: #pragma omp parallel reduction (inscan, + : a, foo(x)) reduction (abc : x, y, z) reduction (task, user_defined_value : x, y, z) reduction (inscan, max : a, foo(x))

#pragma omp parallel allocate (omp_high_bw_mem_alloc : m, n[1:5]) allocate (no, allo, cator) allocate (user_defined_test : m, n[1:5])
PASS: #pragma omp parallel allocate (omp_high_bw_mem_alloc: m, n[1:5]) allocate (no, allo, cator) allocate (m, n[1:5])

// invalid test without paired validation.
#pragma omp parallel private (a[foo(x, goo(x, y)):100], b[1:30], c) num_threads (3*5+4/(7+10)) allocate (omp_user_defined_mem_alloc : m, n[1:5]) allocate (no, allo, cator)

#pragma omp parallel private (a, b, c) private (a, b, e) firstprivate (foo(x), y), shared (a, b, c[1:10]) // invalid test without paired validation.

#pragma omp parallel  private (a[foo(x, goo(x, y)):100], b[1:30], c) firstprivate (foo(x), y), shared (a, b, c[1:10]) num_threads (4)

#pragma omp parallel reduction (tasktest : x11, y, z) allocate (user_defined_test : m, n[1:5]) allocate (omp_high_bw_mem_alloc : m, n[1:5]) reduction (inscan, max : a, foo(x))
