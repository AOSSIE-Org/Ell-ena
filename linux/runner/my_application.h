#ifndef FLUTTER_MY_APPLICATION_H_
#define FLUTTER_MY_APPLICATION_H_

#include <gtk/gtk.h>

G_BEGIN_DECLS

G_DECLARE_FINAL_TYPE(MyApplication, my_application, MY, APPLICATION,

                     GtkApplication)

MyApplication *my_application_new();

G_END_DECLS

#endif 