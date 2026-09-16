#ifndef MBEDTLS_THREADING_ALT_H
#define MBEDTLS_THREADING_ALT_H

/* eli alternative threading backend: mbedtls only needs an opaque handle; the
 * C11 mutex is allocated and managed by lss_runtime.c. Keeping the struct
 * opaque lets mbedtls compile without c11threads headers. */
typedef struct mbedtls_threading_mutex_t {
	void *ctx;
} mbedtls_threading_mutex_t;

#endif /* MBEDTLS_THREADING_ALT_H */
