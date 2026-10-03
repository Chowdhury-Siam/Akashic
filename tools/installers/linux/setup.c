/* Native GTK 3 UI; uses the same libraries as Yutaka's Linux app. */
#include <gtk/gtk.h>
#include <gio/gio.h>
#include <string.h>

typedef struct {
  GtkWidget *window, *folder, *browse, *shortcut, *action, *close, *title_close;
  GtkWidget *headline, *phase, *status, *progress, *spinner;
  GSubprocess *process;
  GDataInputStream *output;
  GString *errors;
  gchar *payload;
  gboolean busy, installed;
} Setup;

static void class_add(GtkWidget *widget, const gchar *name) {
  gtk_style_context_add_class(gtk_widget_get_style_context(widget), name);
}

static GtkWidget *label_new(const gchar *text, const gchar *style) {
  GtkWidget *label = gtk_label_new(text);
  gtk_label_set_xalign(GTK_LABEL(label), 0);
  gtk_label_set_line_wrap(GTK_LABEL(label), TRUE);
  gtk_label_set_max_width_chars(GTK_LABEL(label), 52);
  if (style) class_add(label, style);
  return label;
}

static void set_busy(Setup *setup, gboolean busy) {
  setup->busy = busy;
  gboolean animations = TRUE;
  g_object_get(gtk_settings_get_default(), "gtk-enable-animations", &animations, NULL);
  if (busy && animations) gtk_spinner_start(GTK_SPINNER(setup->spinner));
  else gtk_spinner_stop(GTK_SPINNER(setup->spinner));
  gtk_widget_set_visible(setup->spinner, busy && animations);
  gtk_widget_set_sensitive(setup->folder, !busy && !setup->installed);
  gtk_widget_set_sensitive(setup->browse, !busy && !setup->installed);
  gtk_widget_set_sensitive(setup->shortcut, !busy && !setup->installed);
  gtk_widget_set_sensitive(setup->action, !busy);
  gtk_widget_set_sensitive(setup->close, !busy);
  gtk_widget_set_sensitive(setup->title_close, !busy);
}

static gboolean on_delete(GtkWidget *widget, GdkEvent *event, gpointer data) {
  (void)widget; (void)event;
  return ((Setup *)data)->busy; /* Finish the atomic install before closing. */
}

static void close_clicked(GtkButton *button, gpointer data) {
  (void)button;
  gtk_widget_destroy(((Setup *)data)->window);
}

static gboolean key_pressed(GtkWidget *widget, GdkEventKey *event, gpointer data) {
  (void)widget;
  if (event->keyval != GDK_KEY_Escape) return FALSE;
  Setup *setup = data;
  if (!setup->busy) gtk_widget_destroy(setup->window);
  return TRUE;
}

static gboolean draw_chart(GtkWidget *widget, cairo_t *cr, gpointer data) {
  (void)data;
  const gdouble points[][2] = {{0,.75},{.15,.62},{.29,.70},{.42,.36},{.57,.48},{.72,.18},{.85,.30},{1,.06}};
  gdouble width = gtk_widget_get_allocated_width(widget), height = gtk_widget_get_allocated_height(widget);
  cairo_set_source_rgb(cr, .15, .18, .21);
  cairo_set_line_width(cr, 1);
  cairo_move_to(cr, 0, height * .9); cairo_line_to(cr, width, height * .9); cairo_stroke(cr);
  cairo_set_source_rgb(cr, 0, .74, .57);
  cairo_set_line_width(cr, 2.5);
  for (guint i = 0; i < G_N_ELEMENTS(points); i++) {
    if (i == 0) cairo_move_to(cr, points[i][0] * width, points[i][1] * height);
    else cairo_line_to(cr, points[i][0] * width, points[i][1] * height);
  }
  cairo_stroke(cr);
  return FALSE;
}

static void browse_clicked(GtkButton *button, gpointer data) {
  (void)button;
  Setup *setup = data;
  GtkWidget *dialog = gtk_file_chooser_dialog_new(
      "Choose where to create the Yutaka folder", GTK_WINDOW(setup->window),
      GTK_FILE_CHOOSER_ACTION_SELECT_FOLDER, "Cancel", GTK_RESPONSE_CANCEL,
      "Choose folder", GTK_RESPONSE_ACCEPT, NULL);
  gtk_file_chooser_set_current_folder(GTK_FILE_CHOOSER(dialog), g_get_home_dir());
  if (gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_ACCEPT) {
    gchar *parent = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
    gchar *folder = g_build_filename(parent, "Yutaka", NULL);
    gtk_entry_set_text(GTK_ENTRY(setup->folder), folder);
    g_free(folder); g_free(parent);
  }
  gtk_widget_destroy(dialog);
}

static void install_finished(GObject *source, GAsyncResult *result, gpointer data) {
  Setup *setup = data;
  GError *error = NULL;
  gboolean success = g_subprocess_wait_check_finish(G_SUBPROCESS(source), result, &error);
  if (success) {
    setup->installed = TRUE;
    gtk_progress_bar_set_fraction(GTK_PROGRESS_BAR(setup->progress), 1);
    gtk_label_set_text(GTK_LABEL(setup->status), "Yutaka is ready. Open it from your app menu anytime.");
    gtk_label_set_text(GTK_LABEL(setup->headline), "Make yourself\nat home.");
    gtk_label_set_text(GTK_LABEL(setup->phase), "INSTALLATION COMPLETE");
    gtk_button_set_label(GTK_BUTTON(setup->action), "Launch Yutaka");
    gtk_button_set_label(GTK_BUTTON(setup->close), "Done");
  } else {
    const gchar *message = setup->errors->len ? setup->errors->str : (error ? error->message : "Installation failed. Please try again.");
    gtk_label_set_text(GTK_LABEL(setup->status), message);
    gtk_button_set_label(GTK_BUTTON(setup->action), "Try again");
    gtk_label_set_text(GTK_LABEL(setup->phase), "INSTALLATION FAILED");
    class_add(setup->status, "error");
    class_add(setup->phase, "error");
  }
  g_clear_error(&error);
  g_clear_object(&setup->output);
  g_clear_object(&setup->process);
  set_busy(setup, FALSE);
}

static void read_progress(GObject *source, GAsyncResult *result, gpointer data) {
  Setup *setup = data;
  GError *error = NULL;
  gsize length = 0;
  gchar *line = g_data_input_stream_read_line_finish(G_DATA_INPUT_STREAM(source), result, &length, &error);
  if (line) {
    if (g_str_has_prefix(line, "PROGRESS:")) {
      gchar **parts = g_strsplit(line, ":", 3);
      if (g_strv_length(parts) == 3) {
        gdouble fraction = g_ascii_strtod(parts[1], NULL) / 100.0;
        gtk_progress_bar_set_fraction(GTK_PROGRESS_BAR(setup->progress), CLAMP(fraction, 0, 1));
        gchar *percent = g_strdup_printf("INSTALLING YUTAKA · %.0f%%", fraction * 100);
        gtk_label_set_text(GTK_LABEL(setup->phase), percent);
        gtk_label_set_text(GTK_LABEL(setup->status), parts[2]);
        g_free(percent);
      }
      g_strfreev(parts);
    } else if (length && setup->errors->len < 4096) {
      g_string_append_printf(setup->errors, "%s\n", line);
    }
    g_free(line);
    g_data_input_stream_read_line_async(setup->output, G_PRIORITY_DEFAULT, NULL, read_progress, setup);
    return;
  }
  if (error) { g_string_append(setup->errors, error->message); g_clear_error(&error); }
  g_subprocess_wait_check_async(setup->process, NULL, install_finished, setup);
}

static void action_clicked(GtkButton *button, gpointer data) {
  (void)button;
  Setup *setup = data;
  GError *error = NULL;
  if (setup->installed) {
    gchar *launcher = g_build_filename(g_get_home_dir(), ".local/bin/yutaka", NULL);
    GSubprocess *app = g_subprocess_new(G_SUBPROCESS_FLAGS_NONE, &error, launcher, NULL);
    g_free(launcher);
    if (app) { g_object_unref(app); gtk_widget_destroy(setup->window); }
    else { gtk_label_set_text(GTK_LABEL(setup->status), error->message); g_clear_error(&error); }
    return;
  }
  const gchar *folder = gtk_entry_get_text(GTK_ENTRY(setup->folder));
  if (!g_path_is_absolute(folder)) {
    gtk_label_set_text(GTK_LABEL(setup->status), "Choose an absolute folder path for Yutaka.");
    gtk_widget_grab_focus(setup->folder);
    return;
  }
  gchar *backend = g_build_filename(setup->payload, "install.sh", NULL);
  const gchar *shortcut = gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(setup->shortcut)) ? "true" : "false";
  g_string_truncate(setup->errors, 0);
  setup->process = g_subprocess_new(G_SUBPROCESS_FLAGS_STDOUT_PIPE | G_SUBPROCESS_FLAGS_STDERR_MERGE,
                                  &error, "bash", backend, setup->payload, folder, shortcut, NULL);
  g_free(backend);
  if (!setup->process) {
    gtk_label_set_text(GTK_LABEL(setup->status), error->message);
    g_clear_error(&error);
    return;
  }
  set_busy(setup, TRUE);
  gtk_style_context_remove_class(gtk_widget_get_style_context(setup->status), "error");
  gtk_style_context_remove_class(gtk_widget_get_style_context(setup->phase), "error");
  gtk_progress_bar_set_fraction(GTK_PROGRESS_BAR(setup->progress), 0);
  gtk_label_set_text(GTK_LABEL(setup->headline), "Getting Yutaka\nready for you.");
  gtk_label_set_text(GTK_LABEL(setup->phase), "INSTALLING YUTAKA");
  gtk_label_set_text(GTK_LABEL(setup->status), "Preparing installation…");
  setup->output = g_data_input_stream_new(g_subprocess_get_stdout_pipe(setup->process));
  g_data_input_stream_read_line_async(setup->output, G_PRIORITY_DEFAULT, NULL, read_progress, setup);
}

static gboolean quit_check(gpointer data) {
  gtk_widget_destroy(((Setup *)data)->window);
  return G_SOURCE_REMOVE;
}

int main(int argc, char **argv) {
  gboolean check_ui = argc > 2 && strcmp(argv[2], "--check-ui") == 0;
  if (argc < 2) { g_printerr("Missing installer payload folder.\n"); return 2; }
  Setup setup = {0};
  setup.payload = g_canonicalize_filename(argv[1], NULL);
  setup.errors = g_string_new(NULL);
  if (!gtk_init_check(NULL, NULL)) {
    g_printerr("A desktop display is required. For terminal installation use --install.\n");
    g_free(setup.payload); g_string_free(setup.errors, TRUE); return 1;
  }
  g_set_application_name("Yutaka Setup");
  GtkCssProvider *css = gtk_css_provider_new();
  const gchar *styles =
      "window, dialog { background-color:#0F1216; color:#F3F5F6; font-family:Inter,Sans; font-size:15px; }"
      "window { border:1px solid #272F35; }"
      "headerbar { background:#13181D; border-bottom:1px solid #272F35; box-shadow:none; padding:14px 20px; }"
      "window decoration { border:1px solid #272F35; box-shadow:none; }"
      ".sidebar { background:#13181D; border-right:1px solid #272F35; padding:42px 32px 28px; }"
      ".content { padding:42px 44px 28px; } .brand { font-size:30px; font-weight:700; }"
      ".header-title { font-size:18px; font-weight:700; } .eyebrow { font-size:11px; font-weight:600; letter-spacing:1px; }"
      ".headline { font-size:36px; font-weight:700; } .muted { color:#ADB5BB; }"
      ".phase { font-size:12px; font-weight:600; color:#00BD91; } .error { color:#FF5C7A; }"
      "entry { background:#192126; color:#F3F5F6; border:1px solid #343D43; border-radius:10px; padding:10px; }"
      "entry:focus { border-color:#00BD91; } entry selection { background:#00BD91; color:#071C16; }"
      "button { background:#192126; color:#F3F5F6; border:1px solid #343D43; border-radius:12px; padding:12px 20px; box-shadow:none; text-shadow:none; }"
      "button:hover { background:#20282D; } button:focus { border-color:#00BD91; }"
      "button.primary { background:#00BD91; color:#071C16; border-color:#00BD91; font-weight:700; }"
      "button.primary:hover { background:#27C6A0; } button:disabled { opacity:0.55; }"
      "button.title-close { border:0; background:transparent; padding:4px 12px; font-size:24px; color:#ADB5BB; }"
      "checkbutton { color:#ADB5BB; } checkbutton check { background:#192126; border:1px solid #343D43; border-radius:4px; }"
      "checkbutton check:checked { background:#00BD91; color:#071C16; border-color:#00BD91; } spinner { color:#00BD91; }"
      "progressbar trough { background:#272F35; border:0; border-radius:4px; min-height:6px; }"
      "progressbar progress { background:#00BD91; border-radius:4px; min-height:6px; }";
  GError *css_error = NULL;
  if (!gtk_css_provider_load_from_data(css, styles, -1, &css_error)) {
    g_printerr("Installer theme error: %s\n", css_error->message);
    g_error_free(css_error); g_object_unref(css);
    g_free(setup.payload); g_string_free(setup.errors, TRUE); return 1;
  }
  gtk_style_context_add_provider_for_screen(gdk_screen_get_default(), GTK_STYLE_PROVIDER(css), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
  g_object_unref(css);
  setup.window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(setup.window), "Install Yutaka");
  gtk_window_set_default_size(GTK_WINDOW(setup.window), 960, 640);
  gtk_window_set_position(GTK_WINDOW(setup.window), GTK_WIN_POS_CENTER);
  gchar *icon_path = g_build_filename(setup.payload, "icon.png", NULL);
  gtk_window_set_icon_from_file(GTK_WINDOW(setup.window), icon_path, NULL);
  GtkWidget *header = gtk_header_bar_new();
  gtk_header_bar_set_show_close_button(GTK_HEADER_BAR(header), FALSE);
  GtkWidget *header_brand = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12);
  GdkPixbuf *small = gdk_pixbuf_new_from_file_at_scale(icon_path, 38, 38, TRUE, NULL);
  if (small) { gtk_box_pack_start(GTK_BOX(header_brand), gtk_image_new_from_pixbuf(small), FALSE, FALSE, 0); g_object_unref(small); }
  GtkWidget *header_text = gtk_box_new(GTK_ORIENTATION_VERTICAL, 3);
  gtk_box_pack_start(GTK_BOX(header_text), label_new("Yutaka", "header-title"), FALSE, FALSE, 0);
  GtkWidget *subtitle = label_new("DESKTOP SETUP", "eyebrow"); class_add(subtitle, "muted");
  gtk_label_set_line_wrap(GTK_LABEL(subtitle), FALSE);
  gtk_box_pack_start(GTK_BOX(header_text), subtitle, FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(header_brand), header_text, FALSE, FALSE, 0);
  gtk_header_bar_pack_start(GTK_HEADER_BAR(header), header_brand);
  setup.title_close = gtk_button_new_with_label("×");
  class_add(setup.title_close, "title-close");
  gtk_widget_set_tooltip_text(setup.title_close, "Close installer");
  atk_object_set_name(gtk_widget_get_accessible(setup.title_close), "Close installer");
  gtk_header_bar_pack_end(GTK_HEADER_BAR(header), setup.title_close);
  gtk_window_set_titlebar(GTK_WINDOW(setup.window), header);

  GtkWidget *root = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
  gtk_container_add(GTK_CONTAINER(setup.window), root);
  GtkWidget *sidebar = gtk_box_new(GTK_ORIENTATION_VERTICAL, 16);
  class_add(sidebar, "sidebar");
  gtk_widget_set_size_request(sidebar, 244, -1);
  GdkPixbuf *icon = gdk_pixbuf_new_from_file_at_scale(icon_path, 92, 92, TRUE, NULL);
  g_free(icon_path);
  if (icon) {
    GtkWidget *image = gtk_image_new_from_pixbuf(icon);
    gtk_widget_set_halign(image, GTK_ALIGN_START);
    gtk_box_pack_start(GTK_BOX(sidebar), image, FALSE, FALSE, 0); g_object_unref(icon);
  }
  gtk_box_pack_start(GTK_BOX(sidebar), label_new("Yutaka", "brand"), FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(sidebar), label_new("Your finances,\nin your control.", "muted"), FALSE, FALSE, 0);
  GtkWidget *chart = gtk_drawing_area_new();
  gtk_widget_set_size_request(chart, 180, 72);
  gtk_widget_set_margin_top(chart, 42);
  g_signal_connect(chart, "draw", G_CALLBACK(draw_chart), NULL);
  gtk_box_pack_start(GTK_BOX(sidebar), chart, FALSE, FALSE, 0);
  GtkWidget *spacer = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
  gtk_box_pack_start(GTK_BOX(sidebar), spacer, TRUE, TRUE, 0);
  gtk_box_pack_start(GTK_BOX(sidebar), label_new("LOCAL FIRST · PRIVATE", "phase"), FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(sidebar), label_new("Linux desktop", "muted"), FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(root), sidebar, FALSE, FALSE, 0);

  GtkWidget *content = gtk_box_new(GTK_ORIENTATION_VERTICAL, 14);
  class_add(content, "content");
  setup.headline = label_new("Your finances.\nYour control.", "headline");
  gtk_box_pack_start(GTK_BOX(content), setup.headline, FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(content), label_new("Track accounts, expenses and plans in one place.", "muted"), FALSE, FALSE, 0);
  GtkWidget *options = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10);
  gtk_widget_set_margin_top(options, 14);
  gtk_box_pack_start(GTK_BOX(options), label_new("Install location", "muted"), FALSE, FALSE, 0);
  GtkWidget *row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10);
  setup.folder = gtk_entry_new();
  atk_object_set_name(gtk_widget_get_accessible(setup.folder), "Install location");
  gchar *default_folder = g_build_filename(g_get_home_dir(), ".local/opt/yutaka", NULL);
  gchar *location_path = g_build_filename(g_get_user_data_dir(), "yutaka-installer-location", NULL);
  gchar *previous_folder = NULL;
  if (g_file_get_contents(location_path, &previous_folder, NULL, NULL)) {
    g_strchomp(previous_folder);
    gchar *previous_app = g_build_filename(previous_folder, "Yutaka.AppImage", NULL);
    if (g_path_is_absolute(previous_folder) && g_file_test(previous_app, G_FILE_TEST_IS_EXECUTABLE)) {
      g_free(default_folder); default_folder = g_strdup(previous_folder);
    }
    g_free(previous_app);
  }
  g_free(previous_folder); g_free(location_path);
  gtk_entry_set_text(GTK_ENTRY(setup.folder), default_folder); g_free(default_folder);
  setup.browse = gtk_button_new_with_label("Browse…");
  gtk_box_pack_start(GTK_BOX(row), setup.folder, TRUE, TRUE, 0);
  gtk_box_pack_start(GTK_BOX(row), setup.browse, FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(options), row, FALSE, FALSE, 0);
  setup.shortcut = gtk_check_button_new_with_label("Create a desktop shortcut");
  gtk_box_pack_start(GTK_BOX(options), setup.shortcut, FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(content), options, FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(content), gtk_box_new(GTK_ORIENTATION_VERTICAL, 0), TRUE, TRUE, 0);
  setup.phase = label_new("READY TO INSTALL", "phase");
  gtk_box_pack_start(GTK_BOX(content), setup.phase, FALSE, FALSE, 0);
  setup.progress = gtk_progress_bar_new();
  atk_object_set_name(gtk_widget_get_accessible(setup.progress), "Installation progress");
  gtk_box_pack_start(GTK_BOX(content), setup.progress, FALSE, FALSE, 0);
  setup.status = label_new("Your accounts, transactions and settings stay in place.", "muted");
  gtk_label_set_max_width_chars(GTK_LABEL(setup.status), 65);
  GtkWidget *feedback = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10);
  setup.spinner = gtk_spinner_new();
  gtk_widget_set_size_request(setup.spinner, 20, 20);
  gtk_widget_set_no_show_all(setup.spinner, TRUE);
  gtk_box_pack_start(GTK_BOX(feedback), setup.spinner, FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(feedback), setup.status, TRUE, TRUE, 0);
  gtk_box_pack_start(GTK_BOX(content), feedback, FALSE, FALSE, 0);
  GtkWidget *actions = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12);
  gtk_widget_set_margin_top(actions, 14);
  gtk_widget_set_halign(actions, GTK_ALIGN_END);
  setup.close = gtk_button_new_with_label("Cancel");
  setup.action = gtk_button_new_with_label("Install Yutaka");
  class_add(setup.action, "primary");
  gtk_widget_set_size_request(setup.action, 170, 48);
  gtk_box_pack_start(GTK_BOX(actions), setup.close, FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(actions), setup.action, FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(content), actions, FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(root), content, TRUE, TRUE, 0);
  g_signal_connect(setup.browse, "clicked", G_CALLBACK(browse_clicked), &setup);
  g_signal_connect(setup.action, "clicked", G_CALLBACK(action_clicked), &setup);
  g_signal_connect(setup.close, "clicked", G_CALLBACK(close_clicked), &setup);
  g_signal_connect(setup.title_close, "clicked", G_CALLBACK(close_clicked), &setup);
  g_signal_connect(setup.window, "key-press-event", G_CALLBACK(key_pressed), &setup);
  g_signal_connect(setup.window, "delete-event", G_CALLBACK(on_delete), &setup);
  g_signal_connect(setup.window, "destroy", G_CALLBACK(gtk_main_quit), NULL);
  gtk_widget_show_all(setup.window);
  gtk_widget_set_can_default(setup.action, TRUE);
  gtk_widget_grab_default(setup.action);
  gtk_window_set_focus(GTK_WINDOW(setup.window), setup.action);
  gtk_editable_select_region(GTK_EDITABLE(setup.folder), 0, 0);
  if (check_ui) g_idle_add(quit_check, &setup);
  gtk_main();
  g_free(setup.payload); g_string_free(setup.errors, TRUE);
  return 0;
}
