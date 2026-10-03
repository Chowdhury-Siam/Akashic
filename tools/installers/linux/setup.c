/* Native GTK 3 UI; uses the same libraries as Yutaka's Linux app. */
#include <gtk/gtk.h>
#include <gio/gio.h>
#include <string.h>

typedef struct {
  GtkWidget *window, *folder, *browse, *shortcut, *action, *close, *status, *progress, *spinner;
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
  if (busy) gtk_spinner_start(GTK_SPINNER(setup->spinner));
  else gtk_spinner_stop(GTK_SPINNER(setup->spinner));
  gtk_widget_set_visible(setup->spinner, busy);
  gtk_widget_set_sensitive(setup->folder, !busy && !setup->installed);
  gtk_widget_set_sensitive(setup->browse, !busy && !setup->installed);
  gtk_widget_set_sensitive(setup->shortcut, !busy && !setup->installed);
  gtk_widget_set_sensitive(setup->action, !busy);
  gtk_widget_set_sensitive(setup->close, !busy);
}

static gboolean on_delete(GtkWidget *widget, GdkEvent *event, gpointer data) {
  (void)widget; (void)event;
  return ((Setup *)data)->busy; /* Finish the atomic install before closing. */
}

static void close_clicked(GtkButton *button, gpointer data) {
  (void)button;
  gtk_widget_destroy(((Setup *)data)->window);
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
    gtk_progress_bar_set_text(GTK_PROGRESS_BAR(setup->progress), "Installed");
    gtk_label_set_text(GTK_LABEL(setup->status), "Yutaka is ready. Open it from your app menu anytime.");
    gtk_button_set_label(GTK_BUTTON(setup->action), "Launch Yutaka");
  } else {
    const gchar *message = setup->errors->len ? setup->errors->str : (error ? error->message : "Installation failed. Please try again.");
    gtk_label_set_text(GTK_LABEL(setup->status), message);
    gtk_progress_bar_set_text(GTK_PROGRESS_BAR(setup->progress), "Please try again");
    gtk_button_set_label(GTK_BUTTON(setup->action), "Try again");
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
        gchar *percent = g_strdup_printf("%.0f%%", fraction * 100);
        gtk_progress_bar_set_text(GTK_PROGRESS_BAR(setup->progress), percent);
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
      ".card { background:#13181D; border:1px solid #272F35; border-radius:22px; padding:24px; }"
      ".title { font-size:30px; font-weight:700; }"
      ".muted { color:#ADB5BB; } .section { font-weight:600; }"
      "entry { background:#192126; color:#F3F5F6; border:1px solid #343D43; border-radius:12px; padding:10px; }"
      "entry:focus { border-color:#00BD91; }"
      "entry selection { background:#00BD91; color:#071C16; }"
      "button { background:#192126; color:#F3F5F6; border:1px solid #343D43; border-radius:14px; padding:12px 20px; box-shadow:none; text-shadow:none; }"
      "button:hover { background:#20282D; } button:focus { border-color:#00BD91; }"
      "button.primary { background:#00BD91; color:#071C16; border-color:#00BD91; font-weight:700; }"
      "button.primary:hover { background:#27C6A0; } button:disabled { opacity:0.55; }"
      "checkbutton { color:#F3F5F6; } checkbutton check { background:#192126; border:1px solid #343D43; border-radius:4px; }"
      "checkbutton check:checked { background:#00BD91; color:#071C16; border-color:#00BD91; }"
      "spinner { color:#00BD91; }"
      "progressbar trough { background:#20282D; border:0; border-radius:8px; min-height:8px; }"
      "progressbar progress { background:#00BD91; border-radius:8px; min-height:8px; }";
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
  gtk_window_set_default_size(GTK_WINDOW(setup.window), 640, 520);
  gtk_window_set_position(GTK_WINDOW(setup.window), GTK_WIN_POS_CENTER);
  gchar *icon_path = g_build_filename(setup.payload, "icon.png", NULL);
  gtk_window_set_icon_from_file(GTK_WINDOW(setup.window), icon_path, NULL);
  GtkWidget *root = gtk_box_new(GTK_ORIENTATION_VERTICAL, 20);
  gtk_container_set_border_width(GTK_CONTAINER(root), 28);
  gtk_container_add(GTK_CONTAINER(setup.window), root);
  GtkWidget *header = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 16);
  GdkPixbuf *icon = gdk_pixbuf_new_from_file_at_scale(icon_path, 88, 88, TRUE, NULL);
  g_free(icon_path);
  if (icon) { gtk_box_pack_start(GTK_BOX(header), gtk_image_new_from_pixbuf(icon), FALSE, FALSE, 0); g_object_unref(icon); }
  GtkWidget *titles = gtk_box_new(GTK_ORIENTATION_VERTICAL, 6);
  gtk_box_pack_start(GTK_BOX(titles), label_new("Welcome to Yutaka", "title"), FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(titles), label_new("Your finances, in your control.", "muted"), FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(header), titles, TRUE, TRUE, 0);
  gtk_box_pack_start(GTK_BOX(root), header, FALSE, FALSE, 0);
  GtkWidget *card = gtk_box_new(GTK_ORIENTATION_VERTICAL, 16);
  class_add(card, "card");
  gtk_box_pack_start(GTK_BOX(card), label_new("Install location", "section"), FALSE, FALSE, 0);
  GtkWidget *row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10);
  setup.folder = gtk_entry_new();
  gchar *default_folder = g_build_filename(g_get_home_dir(), ".local/opt/yutaka", NULL);
  gchar *location_path = g_build_filename(g_get_user_data_dir(), "yutaka-installer-location", NULL);
  gchar *previous_folder = NULL;
  if (g_file_get_contents(location_path, &previous_folder, NULL, NULL)) {
    g_strchomp(previous_folder);
    gchar *previous_app = g_build_filename(previous_folder, "Yutaka.AppImage", NULL);
    if (g_path_is_absolute(previous_folder) && g_file_test(previous_app, G_FILE_TEST_IS_EXECUTABLE)) {
      g_free(default_folder);
      default_folder = g_strdup(previous_folder);
    }
    g_free(previous_app);
  }
  g_free(previous_folder); g_free(location_path);
  gtk_entry_set_text(GTK_ENTRY(setup.folder), default_folder); g_free(default_folder);
  setup.browse = gtk_button_new_with_label("Browse…");
  gtk_box_pack_start(GTK_BOX(row), setup.folder, TRUE, TRUE, 0);
  gtk_box_pack_start(GTK_BOX(row), setup.browse, FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(card), row, FALSE, FALSE, 0);
  setup.shortcut = gtk_check_button_new_with_label("Create a desktop shortcut");
  gtk_box_pack_start(GTK_BOX(card), setup.shortcut, FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(card), label_new("Yutaka will appear in your app menu. Your accounts, transactions and settings stay in place during an upgrade.", "muted"), FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(root), card, TRUE, TRUE, 0);
  setup.status = label_new("Ready when you are.", "muted");
  GtkWidget *feedback = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12);
  setup.spinner = gtk_spinner_new();
  gtk_widget_set_size_request(setup.spinner, 20, 20);
  gtk_widget_set_no_show_all(setup.spinner, TRUE);
  gtk_box_pack_start(GTK_BOX(feedback), setup.spinner, FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(feedback), setup.status, TRUE, TRUE, 0);
  gtk_box_pack_start(GTK_BOX(root), feedback, FALSE, FALSE, 0);
  setup.progress = gtk_progress_bar_new();
  gtk_progress_bar_set_show_text(GTK_PROGRESS_BAR(setup.progress), TRUE);
  gtk_progress_bar_set_text(GTK_PROGRESS_BAR(setup.progress), "");
  gtk_box_pack_start(GTK_BOX(root), setup.progress, FALSE, FALSE, 0);
  GtkWidget *actions = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12);
  gtk_widget_set_halign(actions, GTK_ALIGN_END);
  setup.close = gtk_button_new_with_label("Close");
  setup.action = gtk_button_new_with_label("Install Yutaka");
  class_add(setup.action, "primary");
  gtk_box_pack_start(GTK_BOX(actions), setup.close, FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(actions), setup.action, FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(root), actions, FALSE, FALSE, 0);
  g_signal_connect(setup.browse, "clicked", G_CALLBACK(browse_clicked), &setup);
  g_signal_connect(setup.action, "clicked", G_CALLBACK(action_clicked), &setup);
  g_signal_connect(setup.close, "clicked", G_CALLBACK(close_clicked), &setup);
  g_signal_connect(setup.window, "delete-event", G_CALLBACK(on_delete), &setup);
  g_signal_connect(setup.window, "destroy", G_CALLBACK(gtk_main_quit), NULL);
  gtk_widget_show_all(setup.window);
  gtk_widget_grab_focus(setup.action);
  if (check_ui) g_idle_add(quit_check, &setup);
  gtk_main();
  g_free(setup.payload); g_string_free(setup.errors, TRUE);
  return 0;
}
