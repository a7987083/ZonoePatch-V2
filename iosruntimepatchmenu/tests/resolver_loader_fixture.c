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
