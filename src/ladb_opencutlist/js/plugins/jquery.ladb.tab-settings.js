+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTabSettings = function (element, options, opencutlist) {
        LadbAbstractTab.call(this, element, options, opencutlist);

        this.initialLanguage = this.dialog.capabilities.language;

        this.$panelGlobal = $('#ladb_settings_panel_global', this.$element);
        this.$panelModel = $('#ladb_settings_panel_modal', this.$element);

    };
    LadbTabSettings.prototype = new LadbAbstractTab;

    LadbTabSettings.DEFAULTS = {};

    LadbTabSettings.prototype.showReloadAlert = function () {
        var $reloadAlert = $('#ladb_reload_alert', this.$element);
        $reloadAlert
            .show()
            .effect('highlight', {}, 1500);
        $('.ladb-reaload-msg', $reloadAlert).hide();
        var language = this.dialog.capabilities.language === 'auto' ? this.initialLanguage : this.dialog.capabilities.language;
        $('.ladb-reaload-msg-' + language, $reloadAlert).show();
    };

    LadbTabSettings.prototype.bindExportImportGlobalPresetModal = function (actionName, presets, btnActionCallback) {
        var that = this;

        var $modal = that.appendModalInside('ladb_settings_modal_global_presets', 'tabs/settings/_modal-global-presets.twig', {
            actionName: actionName,
            presets: presets
        });

        // Fetch UI elements
        var $btnSelectAll = $('#ladb_settings_btn_select_all', $modal);
        var $btnUnselectAll = $('#ladb_settings_btn_unselect_all', $modal);
        var $btnAction = $('#ladb_settings_btn_action', $modal);

        var fnUpdateRow = function ($row, selected) {
            if (selected === undefined) {    // Undefined  = toggle
                $row.toggleClass('selected')
                selected = $row.hasClass('selected');
            } else {
                if (selected) {
                    $row.addClass('selected');
                } else {
                    $row.removeClass('selected');
                }
            }
            var $i = $('i', $row);
            if (selected) {
                $i.addClass('ladb-opencutlist-icon-check-box-with-check-sign');
                $i.removeClass('ladb-opencutlist-icon-check-box');
            } else {
                $i.removeClass('ladb-opencutlist-icon-check-box-with-check-sign');
                $i.addClass('ladb-opencutlist-icon-check-box');
            }
        };
        var fnUpdateActionStatus = function () {
            $btnAction.prop('disabled', $('.ladb-preset-row.selected').length === 0);
        }

        // Bind buttons
        $btnSelectAll.on('click', function () {
            $('.ladb-preset-row', $modal).each(function () {
                fnUpdateRow($(this), true);
            });
            fnUpdateActionStatus();
            $(this).blur();
            return false;
        });
        $btnUnselectAll.on('click', function () {
            $('.ladb-preset-row', $modal).each(function () {
                fnUpdateRow($(this), false);
            });
            fnUpdateActionStatus();
            $(this).blur();
            return false;
        });
        $btnAction.on('click', function () {

            var pathsFilter = []
            $('.ladb-preset-row', $modal).each(function () {
                if ($(this).hasClass('selected')) {
                    var path = $(this).data('path');
                    pathsFilter.push(path);
                }
            });

            btnActionCallback(pathsFilter);

            // Hide modal
            $modal.modal('hide');

        });
        $('.ladb-preset-row', $modal).on('click', function () {
            fnUpdateRow($(this))
            fnUpdateActionStatus();
        });

        fnUpdateActionStatus();

        // Show modal
        $modal.modal('show');

    };

    LadbTabSettings.prototype.exportGlobalPresets = function () {
        var that = this;

        rubyCallCommand('settings_get_global_presets', null, function (response) {

            if ($.isEmptyObject(response)) {
                that.dialog.notifyErrors([ 'tab.settings.presets.error.no_preset_to_export' ]);
            } else {
                that.bindExportImportGlobalPresetModal('export', response, function (pathsFilter) {

                    rubyCallCommand('settings_export_global_presets_to_json', { paths_filter: pathsFilter }, function (response) {

                        if (response.success) {
                            that.dialog.notify(i18next.t('tab.settings.presets.export_global_presets_success'), 'success');
                        }

                    });

                });
            }

        });

    };

    LadbTabSettings.prototype.importGlobalPresets = function () {
        var that = this;

        rubyCallCommand('settings_load_global_presets_from_json', null, function (response) {

            if (!response.cancelled) {
                if (response.errors) {
                    that.dialog.notifyErrors(response.errors);
                } else {

                    if ($.isEmptyObject(response)) {
                        that.dialog.notifyErrors([ 'tab.settings.presets.error.no_preset_to_import' ]);
                    } else {
                        that.bindExportImportGlobalPresetModal('import', response, function (pathsFilter) {

                            for (var dictionary in response) {
                                for (var section in response[dictionary]) {
                                    for (var name in response[dictionary][section]) {
                                        if (pathsFilter.includes(dictionary + '|' + section + '|' + name)) {
                                            rubyCallCommand('core_set_global_preset', {
                                                dictionary: dictionary,
                                                section: section,
                                                name: name,
                                                values: response[dictionary][section][name]
                                            });
                                        }
                                    }
                                }
                            }

                            that.dialog.alert(null, i18next.t('tab.settings.presets.import_global_presets_success'), function () {
                                rubyCallCommand('core_dialog_hide');
                            }, {
                                okBtnLabel: i18next.t('default.close')
                            });

                        });
                    }

                }
            }

        });

    };

    // Init /////

    LadbTabSettings.prototype.registerCommands = function () {
        LadbAbstractTab.prototype.registerCommands.call(this);

        var that = this;

        this.registerCommand('highlight_panel', function (parameters) {
            setTimeout(function () {     // Use setTimeout to give time to UI to refresh
                switch (parameters.panel) {
                    case 'global':
                        that.$panelGlobal.effect('highlight', {}, 1500);
                        break;
                    case 'model':
                        that.$panelModel.effect('highlight', {}, 1500);
                        break;
                }
            }, 1);
        });
    };

    LadbTabSettings.prototype.bind = function () {
        LadbAbstractTab.prototype.bind.call(this);

        var that = this;

        // Menu /////

        $('#ladb_item_export_global_presets', this.$element).on('click', function () {
            that.exportGlobalPresets();
        });
        $('#ladb_item_import_global_presets', this.$element).on('click', function () {
            that.importGlobalPresets();
        });
        $('#ladb_item_dump_global_presets', this.$element).on('click', function () {
            rubyCallCommand('settings_dump_global_presets');
        });
        $('#ladb_item_dump_model_presets', this.$element).on('click', function () {
            rubyCallCommand('settings_dump_model_presets');
        });
        $('#ladb_item_reset_global_presets', this.$element).on('click', function () {
            that.dialog.confirm(i18next.t('default.caution'), i18next.t('tab.settings.presets.reset_global_presets_confirm'), function () {
                rubyCallCommand('settings_reset_global_presets', null, function () {
                    that.dialog.alert(null, i18next.t('tab.settings.presets.reset_global_presets_success'), function () {
                        rubyCallCommand('core_dialog_hide');
                    }, {
                        okBtnLabel: i18next.t('default.close')
                    });
                });
            }, {
                confirmBtnType: 'danger'
            })
        });
        $('#ladb_item_reset_model_presets', this.$element).on('click', function () {
            that.dialog.confirm(i18next.t('default.caution'), i18next.t('tab.settings.presets.reset_model_presets_confirm'), function () {
                rubyCallCommand('settings_reset_model_presets', null, function () {
                    that.dialog.alert(null, i18next.t('tab.settings.presets.reset_model_presets_success'), function () {
                        rubyCallCommand('core_dialog_hide');
                    }, {
                        okBtnLabel: i18next.t('default.close')
                    });
                });
            }, {
                confirmBtnType: 'danger'
            });
        });

        // Global settings /////

        var $btnReset = $('#ladb_btn_reset', this.$element);
        var $selectLanguage = $('#ladb_select_language', this.$element);
        var $btnWidthUp = $('#ladb_btn_width_up', this.$element);
        var $btnWidthDown = $('#ladb_btn_width_down', this.$element);
        var $btnHeightUp = $('#ladb_btn_height_up', this.$element);
        var $btnHeightDown = $('#ladb_btn_height_down', this.$element);
        var $btnLeftUp = $('#ladb_btn_left_up', this.$element);
        var $btnLeftDown = $('#ladb_btn_left_down', this.$element);
        var $btnTopUp = $('#ladb_btn_top_up', this.$element);
        var $btnTopDown = $('#ladb_btn_top_down', this.$element);
        var $selectPrintMargin = $('#ladb_select_print_margin', this.$element);

        var fnGlobalUpdate = function () {

            // Send to ruby
            rubyCallCommand('settings_dialog_settings', {
                language: that.dialog.capabilities.language,
                print_margin: that.dialog.capabilities.dialog_print_margin
            });

        };
        var fnGlobalFillInputs = function () {
            $selectLanguage.selectpicker('val', that.dialog.capabilities.language);
            $selectPrintMargin.selectpicker('val', that.dialog.capabilities.dialog_print_margin);
        }

        $selectLanguage.selectpicker($.extend(SELECT_PICKER_OPTIONS, { size: that.dialog.capabilities.available_languages.length + 1 }));
        $selectPrintMargin.selectpicker(SELECT_PICKER_OPTIONS);

        fnGlobalFillInputs();

        // Bind
        $selectLanguage.on('change', function () {
            that.dialog.capabilities.language = $selectLanguage.val();
            fnGlobalUpdate();
            that.showReloadAlert();
        });
        $selectPrintMargin.on('change', function () {
            that.dialog.capabilities.dialog_print_margin = parseInt($selectPrintMargin.val());
            fnGlobalUpdate();
        });
        $btnReset.on('click', function () {
            $(this).blur();
            that.dialog.capabilities.language = 'auto';
            that.dialog.capabilities.dialog_print_margin = 0;
            fnGlobalUpdate();
            fnGlobalFillInputs();
            that.showReloadAlert();
            return false;
        });
        $btnWidthUp.on('click', function () {
            $(this).blur();
            rubyCallCommand('settings_dialog_inc_size', {
                inc_width: 20,
                inc_height: 0,
            });
            return false;
        });
        $btnWidthDown.on('click', function () {
            $(this).blur();
            rubyCallCommand('settings_dialog_inc_size', {
                inc_width: -20,
                inc_height: 0,
            });
            return false;
        });
        $btnHeightUp.on('click', function () {
            $(this).blur();
            rubyCallCommand('settings_dialog_inc_size', {
                inc_width: 0,
                inc_height: 20,
            });
            return false;
        });
        $btnHeightDown.on('click', function () {
            $(this).blur();
            rubyCallCommand('settings_dialog_inc_size', {
                inc_width: 0,
                inc_height: -20,
            });
            return false;
        });
        $btnLeftUp.on('click', function () {
            $(this).blur();
            rubyCallCommand('settings_dialog_inc_position', {
                inc_left: 20,
                inc_top: 0,
            });
            return false;
        });
        $btnLeftDown.on('click', function () {
            $(this).blur();
            rubyCallCommand('settings_dialog_inc_position', {
                inc_left: -20,
                inc_top: 0,
            });
            return false;
        });
        $btnTopUp.on('click', function () {
            $(this).blur();
            rubyCallCommand('settings_dialog_inc_position', {
                inc_left: 0,
                inc_top: 20,
            });
            return false;
        });
        $btnTopDown.on('click', function () {
            $(this).blur();
            rubyCallCommand('settings_dialog_inc_position', {
                inc_left: 0,
                inc_top: -20,
            });
            return false;
        });

        // Model Settings /////

        var modelSettings = {};
        var modelLengthFormat = 0;

        // Fetch UI elements
        var $widgetPreset = $('.ladb-widget-preset', that.$element);
        var $selectLengthUnit = $('#ladb_model_select_length_unit', that.$element);
        var $selectLengthFormat = $('#ladb_model_select_length_format', that.$element);
        var $selectLengthPrecision = $('#ladb_model_select_length_precision', that.$element);
        var $inputSuppressUnitsDisplay = $('#ladb_model_input_suppress_units_display', that.$element);
        var $selectMassUnit = $('#ladb_model_select_mass_unit', that.$element);
        var $inputCurrencySymbol = $('#ladb_model_input_currency_symbol', that.$element);

        var fnFetchOptions = function (options) {
            options.mass_unit = parseInt($selectMassUnit.selectpicker('val'));
            options.currency_symbol = $inputCurrencySymbol.val();
        };
        var fnFillInputs = function (options) {
            $selectMassUnit.selectpicker('val', options.mass_unit);
            $inputCurrencySymbol.val(options.currency_symbol);
        };
        var fnAdaptLengthPrecisionToFormat = function () {
            if (modelLengthFormat === 0 /* DECIMAL */ || modelLengthFormat === 2 /* ENGINEERING */) {
                $('.length-unit-decimal', that.$element).show();
                $('.length-unit-fractional', that.$element).hide();
            } else {
                $('.length-unit-decimal', that.$element).hide();
                $('.length-unit-fractional', that.$element).show();
            }
        }
        var fnFillLengthSettings = function(settings) {

            $selectLengthUnit
                .selectpicker('val', settings.length_unit)
                .prop('disabled', settings.length_unit_disabled)
                .selectpicker('refresh')
            ;
            $selectLengthFormat.selectpicker('val', settings.length_format);
            $selectLengthPrecision.selectpicker('val', settings.length_precision);
            $inputSuppressUnitsDisplay
                .prop('checked', !settings.suppress_units_display)
                .prop('disabled', settings.suppress_units_display_disabled)
            ;

            modelLengthFormat = settings.length_format;
            fnAdaptLengthPrecisionToFormat(modelLengthFormat);

        }
        var fnRetrieveModelOptions = function () {

            // Retrieve SU options
            rubyCallCommand('settings_get_length_settings', null, function (response) {

                if (response.errors && response.errors.length > 0) {

                    // No model or error : hide model panel
                    that.$panelModel.hide();

                    return;
                }

                fnFillLengthSettings(response);

                // Retrieve OCL options
                rubyCallCommand('core_get_model_preset', { dictionary: 'settings_model' }, function (response) {

                    var modelOptions = response.preset;
                    fnFillInputs(modelOptions);

                });

            });

        };
        var fnSaveOptions = function () {

            // Fetch options
            fnFetchOptions(modelSettings);

            // Store options
            rubyCallCommand('core_set_model_preset', { dictionary: 'settings_model', values: modelSettings, fire_event:true });

        };

        $widgetPreset.ladbWidgetPreset({
            dialog: that.dialog,
            dictionary: 'settings_model',
            fnFetchOptions: fnFetchOptions,
            fnFillInputs: function (options) {
                fnFillInputs(options);
                fnSaveOptions();
            }
        });
        $selectLengthUnit.selectpicker(SELECT_PICKER_OPTIONS);
        $selectLengthFormat.selectpicker(SELECT_PICKER_OPTIONS);
        $selectLengthPrecision.selectpicker(SELECT_PICKER_OPTIONS);
        $selectMassUnit.selectpicker(SELECT_PICKER_OPTIONS);

        fnRetrieveModelOptions();

        // Bind input & select
        $selectLengthUnit
            .on('change', function () {
                var lengthUnit = parseInt($selectLengthUnit.selectpicker('val'));

                rubyCallCommand('settings_set_length_settings', { length_unit: lengthUnit }, fnFillLengthSettings);

            })
        ;
        $selectLengthFormat
            .on('change', function () {
                var lengthFormat = parseInt($selectLengthFormat.selectpicker('val'));

                rubyCallCommand('settings_set_length_settings', { length_format: lengthFormat }, fnFillLengthSettings);

            })
        ;
        $selectLengthPrecision
            .on('change', function () {
                var lengthPrecision = parseInt($selectLengthPrecision.selectpicker('val'));

                rubyCallCommand('settings_set_length_settings', { length_precision: lengthPrecision }, fnFillLengthSettings);

            })
            .on('show.bs.select', function (e, clickedIndex, isSelected, previousValue) {
                fnAdaptLengthPrecisionToFormat(modelLengthFormat);
            })
        ;
        $inputSuppressUnitsDisplay
            .on('change', function () {
                var suppressUnitsDisplay = !($inputSuppressUnitsDisplay.is(':checked'));

                rubyCallCommand('settings_set_length_settings', { suppress_units_display: suppressUnitsDisplay }, fnFillLengthSettings);

            })
        ;
        $selectMassUnit.on('change', fnSaveOptions);
        $inputCurrencySymbol.on('change', fnSaveOptions);

        // Events

        addEventCallback([ 'on_new_model', 'on_open_model', 'on_activate_model' ], function (params) {
            fnRetrieveModelOptions();
            that.$panelModel.show();
        });
        addEventCallback('on_options_provider_changed', function (params) {
            fnRetrieveModelOptions();
        });

    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.tab.plugin');
            var options = $.extend({}, LadbTabSettings.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.tab.plugin', (data = new LadbTabSettings(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init(option.initializedCallback);
            }
        })
    }

    var old = $.fn.ladbTabSettings;

    $.fn.ladbTabSettings = Plugin;
    $.fn.ladbTabSettings.Constructor = LadbTabSettings;


    // NO CONFLICT
    // =================

    $.fn.ladbTabSettings.noConflict = function () {
        $.fn.ladbTabSettings = old;
        return this;
    }

}(jQuery);