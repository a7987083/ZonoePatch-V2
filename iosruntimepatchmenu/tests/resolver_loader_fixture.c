#include <pthread.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stddef.h>
static int domain,image,klass,method;
int FixtureRun(void){return 42;}
void *il2cpp_domain_get(void){return &domain;}
const void **il2cpp_domain_get_assemblies(const void *d,size_t *n){(void)d;static const void *assemblies[]={&image};*n=1;return assemblies;}
const void *il2cpp_assembly_get_image(const void *a){return a;}
const char *il2cpp_image_get_name(const void *p){(void)p;return "Assembly-CSharp.dll";}
void *il2cpp_class_from_name(const void *i,const char *ns,const char *c){(void)i;(void)ns;(void)c;return &klass;}
const char *il2cpp_class_get_name(void *c){(void)c;return "Fixture";}
const char *il2cpp_class_get_namespace(void *c){(void)c;return "Tests";}
const void *il2cpp_class_get_methods(void *c,void **it){(void)c;if(*it)return NULL;*it=&method;return &method;}
const void *il2cpp_class_get_method_from_name(void *c,const char *name,int count){(void)c;(void)name;(void)count;return &method;}
const char *il2cpp_method_get_name(const void *m){(void)m;return "Run";}
unsigned il2cpp_method_get_param_count(const void *m){(void)m;return 0;}
void *il2cpp_method_get_pointer(const void *m){(void)m;return (void*)FixtureRun;}
static _Atomic unsigned callbackValue;
static pthread_mutex_t invokeMutex=PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t invokeCondition=PTHREAD_COND_INITIALIZER;
static int blockInvoke;
static _Atomic unsigned invokeEntered;
void FixtureBlockInvoke(int block){pthread_mutex_lock(&invokeMutex);blockInvoke=block;if(block)invokeEntered=0;else pthread_cond_broadcast(&invokeCondition);pthread_mutex_unlock(&invokeMutex);}
unsigned FixtureInvokeEntered(void){return invokeEntered;}

void *il2cpp_object_get_class(void *object){(void)object;return &klass;}
void *il2cpp_runtime_invoke(const void *m,void *object,void **params,void **exception){(void)m;(void)object;*exception=NULL;callbackValue=*(unsigned char *)params[0];pthread_mutex_lock(&invokeMutex);invokeEntered=1;while(blockInvoke)pthread_cond_wait(&invokeCondition,&invokeMutex);pthread_mutex_unlock(&invokeMutex);return NULL;}
unsigned FixtureCallbackValue(void){return callbackValue;}

unsigned char FixtureBoolOriginal(uintptr_t a,uintptr_t b,uintptr_t c,uintptr_t d,uintptr_t e,uintptr_t f,uintptr_t g,uintptr_t h){(void)b;(void)c;(void)d;(void)e;(void)f;(void)g;(void)h;return a?1:0;}

size_t il2cpp_image_get_class_count(const void *i){(void)i;return 1;}
void *il2cpp_image_get_class(const void *i,size_t n){(void)i;(void)n;return &klass;}
