/*
 *  Copyright 2019-2021 Tanaka Takayuki (田中喬之)
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 *  Tanaka Takayuki <aharotias2@gmail.com>
 */

using Gdk, Gtk;

namespace Tatap {
    public class SlideImageView : ImageView, EventBox {
        private enum ScalingMode {
            FIT_WIDTH, FIT_PAGE, BY_PERCENTAGE
        }

        public ViewMode view_mode { get; construct; }
        public Tatap.Window main_window { get; construct; }
        public FileList file_list {
            get {
                return _file_list;
            }
            set {
                _file_list = value;
                length_list = new double[_file_list.size];
            }
        }
        public bool controllable { get; set; }
        public string dir_path {
            owned get {
                return file_list.dir_path;
            }
        }
        public bool has_image {
            get {
                return widget_list.size > 0;
            }
        }
        public double position {
            get {
                if (slide_box.orientation == VERTICAL) {
                    return scroll.vadjustment.value / scroll.vadjustment.upper * 100;
                } else {
                    return scroll.hadjustment.value / scroll.hadjustment.upper * 100;
                }
            }
        }
        public int index {
            get {
                return get_location();
            }
        }
        public int page_spacing { get; set; default = 4; }
        public int scroll_interval { get; set; default = 1; }
        public double scroll_amount { get; set; default = 10.0; }
        public double scroll_overlapping { get; set; default = 10.0; }
        private Gee.List<Tatap.Image> widget_list;
        private Box slide_box;
        private ScrolledWindow scroll;
        private FileList _file_list;
        private uint64 size_changed_count;
        private SourceFunc make_view_callback;
        private int saved_width;
        private int saved_height;
        private double[] length_list;
        private ScalingMode scaling_mode = FIT_WIDTH;
        private uint scale_percentage = 0;

        public SlideImageView(Tatap.Window window) {
            Object(
                main_window: window,
                view_mode: ViewMode.SLIDE_VIEW_MODE,
                controllable: true
            );
        }

        public SlideImageView.with_file_list(Window window, FileList file_list) {
            Object(
                main_window: window,
                file_list: file_list,
                view_mode: ViewMode.SLIDE_VIEW_MODE,
                controllable: true
            );
        }

        construct {
            scroll = new ScrolledWindow(null, null);
            {
                slide_box = new Box(VERTICAL, 0);
                scroll.add(slide_box);
                debug("slide view mode scroll added slide box");
            }

            add(scroll);
            size_allocate.connect((allocation) => {
                debug("slide image view size allocate to (%d, %d) current size = (%d, %d)", allocation.width, allocation.height, get_allocated_width(), get_allocated_height());
                if (saved_width != allocation.width) {
                    size_changed_count++;
                    switch (scaling_mode) {
                      case FIT_WIDTH:
                        fit_width();
                        break;
                      case FIT_PAGE:
                        fit_page();
                        break;
                      case BY_PERCENTAGE:
                        scale_by_percentage(scale_percentage);
                        break;
                    }
                }
                saved_width = allocation.width;
            });
            debug("slide view mode added scroll");
        }

        public void fit_width() {
            scaling_mode = FIT_WIDTH;
            size_changed_count++;
            fit_images_by_width.begin();
        }

        public void fit_page() {
            scaling_mode = FIT_PAGE;
            size_changed_count++;
            fit_images_by_height.begin();
        }

        public void scale_by_percentage(uint scale_percentage) {
            scaling_mode = BY_PERCENTAGE;
            this.scale_percentage = scale_percentage;
            size_changed_count++;
            scale_images_by_percentage.begin(scale_percentage);
        }

        private async void fit_images_by_width() {
            if (widget_list == null || widget_list.size == 0) {
                return;
            }
            uint64 tmp = size_changed_count;
            for (int i = 0; i < widget_list.size && tmp == size_changed_count; i++) {
                debug("size_allocated");
                int new_width = scroll.get_allocated_width();
                debug("slide image view resize image %d (%lld) => %d", i, tmp, new_width);
                widget_list[i].scale_fit_in_width(new_width);
                length_list[i] = i > 0 ? length_list[i - 1] + (double) new_width : (double) new_width;
                update_title();
                Idle.add(fit_images_by_width.callback);
                yield;
            }
        }

        private async void fit_images_by_height() {
            if (widget_list == null || widget_list.size == 0) {
                return;
            }
            uint64 tmp = size_changed_count;
            for (int i = 0; i < widget_list.size && tmp == size_changed_count; i++) {
                debug("size_allocated");
                int new_height = scroll.get_allocated_height();
                debug("slide image view resize image %d (%lld) => %d", i, tmp, new_height);
                widget_list[i].scale_fit_in_height(new_height);
                length_list[i] = i > 0 ? length_list[i - 1] + (double) new_height : (double) new_height;
                update_title();
                Idle.add(fit_images_by_height.callback);
                yield;
            }
        }

        private async void scale_images_by_percentage(uint percentage) {
            if (widget_list == null || widget_list.size == 0) {
                return;
            }
            uint64 tmp = size_changed_count;
            for (int i = 0; i < widget_list.size && tmp == size_changed_count; i++) {
                widget_list[i].set_scale_percent(percentage);
                Idle.add(scale_images_by_percentage.callback);
                yield;
                if (slide_box.orientation == VERTICAL) {
                    double new_height = widget_list[i].get_allocated_height();
                    length_list[i] = i > 0 ? length_list[i - 1] + new_height : new_height;
                } else {
                    double new_width = widget_list[i].get_allocated_width();
                    length_list[i] = i > 0 ? length_list[i - 1] + new_width : new_width;
                }
                update_title();
                Idle.add(scale_images_by_percentage.callback);
                yield;
            }
        }

        private bool is_make_view_continue;

        private async void init_async(int index = 0) {
            size_changed_count = 0;
            var saved_cursor = get_window().cursor;
            change_cursor(WATCH);
            Idle.add(init_async.callback);
            yield;
            widget_list = new Gee.ArrayList<Tatap.Image>();
            remove(scroll);
            scroll = new ScrolledWindow(null, null);
            scroll.get_style_context().add_class("image-view");
            scroll.vscrollbar_policy = ALWAYS;
            scroll.hscrollbar_policy = ALWAYS;
            scroll.scroll_event.connect((event) => {
                debug("slide image view scroll to %f", scroll.vadjustment.value);
                if (is_make_view_continue && get_scroll_position() > 0.98) {
                    Idle.add((owned) make_view_callback);
                }
                return false;
            });
            if (slide_box.orientation == VERTICAL) {
                scroll.vadjustment.value_changed.connect(() => {
                    main_window.image_prev_button.sensitive = is_prev_button_sensitive();
                    main_window.image_next_button.sensitive = is_next_button_sensitive();
                    if (is_make_view_continue && get_scroll_position() > 0.98) {
                        Idle.add((owned) make_view_callback);
                    }
                });
            } else {
                scroll.hadjustment.value_changed.connect(() => {
                    main_window.image_prev_button.sensitive = is_prev_button_sensitive();
                    main_window.image_next_button.sensitive = is_next_button_sensitive();
                    if (is_make_view_continue && get_scroll_position() > 0.98) {
                        Idle.add((owned) make_view_callback);
                    }
                });
            }
            add(scroll);
            slide_box = new Box(slide_box.orientation, page_spacing) {
                margin = page_spacing
            };
            scroll.add(slide_box);
            show_all();
            Idle.add(init_async.callback);
            yield;

            make_view_async.begin(index);

            get_window().cursor = saved_cursor;
        }

        private async void make_view_async(int index = 0) {
            is_make_view_continue = true;
            for (int i = 0; i < file_list.size; i++) {
                try {
                    string filename = file_list.get_filename_at(i);
                    string filepath = Path.build_path(Path.DIR_SEPARATOR_S, dir_path, filename);
                    var image_widget = new Tatap.Image(false) {
                        container = scroll,
                        halign = CENTER
                    };
                    image_widget.get_style_context().add_class("image-view");
                    widget_list.add(image_widget);
                    slide_box.pack_start(image_widget, false, false);
                    yield image_widget.open_async(filepath);
                    switch (scaling_mode) {
                      case FIT_WIDTH:
                        image_widget.scale_fit_in_width(get_allocated_width());
                        break;
                      case FIT_PAGE:
                        image_widget.scale_fit_in_height(get_allocated_height());
                        break;
                      case BY_PERCENTAGE:
                        image_widget.set_scale_percent(scale_percentage);
                        break;
                    }
                    image_widget.show_all();
                    Idle.add(make_view_async.callback);
                    yield;
                    double h = (double) image_widget.get_allocated_height();
                    length_list[i] = i > 0 ? length_list[i - 1] + h : h;
                    if (i == index) {
                        scroll.vadjustment.value = length_list[i];
                        Idle.add(make_view_async.callback);
                        yield;
                    } else if (i > index && get_scroll_position() < 0.9) {
                        make_view_callback = make_view_async.callback;
                        yield;
                    }
                } catch (Error e) {
                    main_window.show_error_dialog(e.message);
                }
            }
            is_make_view_continue = false;
        }

        private double get_scroll_position() {
            if (slide_box.orientation == VERTICAL) {
                double position = scroll.vadjustment.value / (scroll.vadjustment.upper - scroll.vadjustment.page_size);
                debug("slide image view scroll position: %f", position);
                return position;
            } else {
                double position = scroll.hadjustment.value / (scroll.hadjustment.upper - scroll.hadjustment.page_size);
                debug("slide image view scroll position: %f", position);
                return position;
            }
        }

        public File get_file() throws Error {
            // TODO
            string filename = file_list.get_filename_at(get_location());
            string filepath = Path.build_path(Path.DIR_SEPARATOR_S, dir_path, filename);
            return File.new_for_path(filepath);
        }

        public bool is_next_button_sensitive() {
            // TODO
            if (slide_box.orientation == VERTICAL) {
                var vadjust = scroll.vadjustment;
                if (vadjust.value < vadjust.upper) {
                    return true;
                } else {
                    return false;
                }
            } else {
                var hadjust = scroll.hadjustment;
                if (hadjust.value < hadjust.upper) {
                    return true;
                } else {
                    return false;
                }
            }
        }

        public bool is_prev_button_sensitive() {
            // TODO
            if (slide_box.orientation == VERTICAL) {
                var vadjust = scroll.vadjustment;
                if (vadjust.value > 0) {
                    return true;
                } else {
                    return false;
                }
            } else {
                var hadjust = scroll.hadjustment;
                if (hadjust.value > 0) {
                    return true;
                } else {
                    return false;
                }
            }
        }

        public async void go_forward_async(int offset = 1) {
            // TODO
            if (slide_box.orientation == VERTICAL) {
                double start = scroll.vadjustment.value;
                double goal = start + scroll.vadjustment.page_size - (scroll.vadjustment.page_size / scroll_overlapping);
                if (goal > scroll.vadjustment.upper) {
                    goal = scroll.vadjustment.upper;
                }
                Timeout.add(scroll_interval, () => {
                    if (scroll.vadjustment.value < goal) {
                        scroll.vadjustment.value += scroll_amount;
                        return true;
                    } else {
                        return false;
                    }
                });
            }
        }

        public async void go_backward_async(int offset = 1) {
            // TODO
            if (slide_box.orientation == VERTICAL) {
                double start = scroll.vadjustment.value;
                double goal = start - scroll.vadjustment.page_size - (scroll.vadjustment.page_size / scroll_overlapping);
                if (goal < 0) {
                    goal = 0.0;
                }
                Timeout.add(scroll_interval, () => {
                    if (scroll.vadjustment.value > goal) {
                        scroll.vadjustment.value -= scroll_amount;
                        return true;
                    } else {
                        return false;
                    }
                });
            }
        }

        public async void open_async(File file) throws Error {
            // TODO
            debug("open %s", file.get_basename());
            yield init_async(file_list.get_index_of(file.get_basename()));
        }

        public async void reopen_async() throws Error {
            // TODO
            yield init_async(get_location());
        }

        public async void open_at_async(int index) throws Error {
            // TODO
            yield init_async(index);
        }

        public void update_title() {
            // TODO
            return;
        }

        public void update() {
            // TODO
            return;
        }

        public void close() {
            // TODO
            return;
        }

        private int get_location() {
            double pos = 0.0;
            if (slide_box.orientation == VERTICAL) {
                pos = scroll.vadjustment.value;
            } else {
                pos = scroll.hadjustment.value;
            }
            for (int i = 0; i < length_list.length; i++) {
                debug("slide image view get location (pos: %f, index = %d, value = %f)", pos, i, length_list[i]);
                if (pos < length_list[i]) {
                    return i;
                }
            }
            return length_list.length - 1;
        }

        private void change_cursor(CursorType cursor_type) {
            get_window().cursor = new Gdk.Cursor.for_display(Gdk.Screen.get_default().get_display(), cursor_type);
        }
    }
}