+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbWidgetPreset = function (element, options, dialog) {
        this.options = options;
        this.$element = $(element);
        this.dialog = dialog;

        this.$dropdown = $('ul', this.$element);
        this.$btn = $('button', this.$element);

    };

    LadbWidgetPreset.DEFAULTS = {
        dictionary: null,
        section: null,
        fnFetchOptions: null,
        fnFillInputs: null
    };

    LadbWidgetPreset.prototype.deletePreset = function (name, noNotification) {
        var that = this;

        this.dialog.confirm(i18next.t('core.preset.delete_confirm_title'), i18next.t('core.preset.delete_confirm', { name: name }), function () {
            rubyCallCommand('core_set_global_preset', {
                dictionary: that.options.dictionary,
                section: that.options.section,
                values: null,
                name: name
            }, function () {
                if (!noNotification) {
                    that.dialog.notify(i18next.t('core.preset.delete_success', { name: name }), 'success');
                }
                that.refresh();
            });
        }, {
            confirmBtnType: 'danger',
            confirmBtnLabel: i18next.t('default.remove')
        });

    };

    LadbWidgetPreset.prototype.saveToPreset = function (name, isNew, noNotification) {
        var that = this;

        var fnDoSave = function () {
            var values = {};
            that.options.fnFetchOptions(values);
            rubyCallCommand('core_set_global_preset', {
                dictionary: that.options.dictionary,
                section: that.options.section,
                values: values,
                name: name
            }, function () {
                if (isNew) {
                    that.refresh();
                    if (!noNotification) {
                        that.dialog.notify(i18next.t('core.preset.new_success', { name: name }), 'success');
                    }
                } else {
                    if (!noNotification) {
                        that.dialog.notify(i18next.t('core.preset.override_success', {name: name ? name : i18next.t('core.preset.user_defaults')}), 'success');
                    }
                }
            });
        };

        if (isNew) {
            fnDoSave();
        } else {
            this.dialog.confirm(i18next.t('core.preset.override_confirm_title'), i18next.t('core.preset.override_confirm', { name: name ? name : i18next.t('core.preset.user_defaults') }), function () {
                fnDoSave();
            });
        }

    };

    LadbWidgetPreset.prototype.restoreFromPreset = function (name, noNotification) {
        var that = this;
        rubyCallCommand('core_get_global_preset', {
            dictionary: that.options.dictionary,
            section: that.options.section,
            name: name
        }, function (response) {
            that.options.fnFillInputs(response.preset);
            if (!noNotification) {
                that.dialog.notify(i18next.t('core.preset.restore_success', { name: name ? name : i18next.t('core.preset.user_defaults') }), 'success');
            }
        });
    };

    LadbWidgetPreset.prototype.refresh = function () {
        var that = this;

        rubyCallCommand('core_list_global_preset_names', { dictionary: this.options.dictionary, section: this.options.section }, function (response) {

            // Replace dropdown content
            that.$dropdown
                .empty()
                .append(Twig.twig({ref: 'components/_widget-preset-dropdown-content.twig'}).render({
                    names: response.names
                }))
            ;

            // Bind help button
            that.dialog.bindHelpButtonsInParent(that.$dropdown);

            // Bind buttons
            $('.ladb-widget-preset-btn-restore-app-defaults', that.$dropdown).on('click', function () {
                rubyCallCommand('core_get_app_defaults', {
                    dictionary: that.options.dictionary,
                    section: that.options.section,
                }, function (response) {
                    that.options.fnFillInputs(response.defaults);
                    that.dialog.notify(i18next.t('core.preset.restore_success', {name: name ? name : i18next.t('core.preset.app_defaults')}), 'success');
                });
            });
            $('.ladb-widget-preset-btn-restore-user-defaults', that.$dropdown).on('click', function () {
                that.restoreFromPreset(null);
            });
            $('.ladb-widget-preset-btn-save-user-defaults', that.$dropdown).on('click', function () {
                that.saveToPreset(null);
            });
            $('.ladb-widget-preset-item', that.$dropdown).each(function (index) {
                var $item = $(this);
                var name = $item.data('name');

                $('.ladb-widget-preset-btn-restore', $item).on('click', function () {
                    that.restoreFromPreset(name);
                });
                $('.ladb-widget-preset-btn-save', $item).on('click', function () {
                    that.saveToPreset(name);
                });
                $('.ladb-widget-preset-btn-delete', $item).on('click', function () {
                    that.deletePreset(name);
                });

            });
            $('.ladb-widget-preset-btn-new', that.$dropdown).on('click', function () {
                that.dialog.prompt(i18next.t('core.preset.new'), i18next.t('core.preset.new_prompt'), '', function (name) {
                    that.saveToPreset(name, true);
                });
            });

            // Setup tooltips
            that.dialog.setupTooltips();

        });

    };

    LadbWidgetPreset.prototype.setSection = function (section) {
        this.options.section = section;
        this.refresh();
    };

    LadbWidgetPreset.prototype.init = function () {
        this.refresh();
    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        var value;
        var elements = this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.widgetPreset');
            var options = $.extend({}, LadbWidgetPreset.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.widgetPreset', (data = new LadbWidgetPreset(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    var old = $.fn.ladbWidgetPreset;

    $.fn.ladbWidgetPreset = Plugin;
    $.fn.ladbWidgetPreset.Constructor = LadbWidgetPreset;


    // NO CONFLICT
    // =================

    $.fn.ladbWidgetPreset.noConflict = function () {
        $.fn.ladbWidgetPreset = old;
        return this;
    }

}(jQuery);