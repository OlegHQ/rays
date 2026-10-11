#include <pthread.h>
#include <stdint.h>
#include <caml/mlvalues.h>
#include <caml/alloc.h>

/* The tag the Objective-C runtime prints for the calling thread. */
CAMLprim value rays_test_thread_tag(value unit)
{
  (void)unit;
  return caml_copy_int64((int64_t)(uintptr_t)pthread_self());
}
