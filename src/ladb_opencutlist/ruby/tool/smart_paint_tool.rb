module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative '../lib/kuix/kuix'
  require_relative '../utils/path_utils'
  require_relative '../utils/color_utils'
  require_relative '../utils/material_utils'
  require_relative '../helper/face_triangles_helper'
  require_relative '../model/attributes/material_attributes'
  require_relative '../worker/cutlist/cutlist_generate_worker'

  class SmartPaintTool < SmartTool

    include FaceTrianglesHelper

    ACTION_PAINT_PARTS = 0
    ACTION_PAINT_EDGES = 1
    ACTION_PAINT_FACES = 2
    ACTION_PICK = 3
    ACTION_PAINT_CLEAN = 4

    ACTION_MODIFIER_1 = 0
    ACTION_MODIFIER_2 = 1
    ACTION_MODIFIER_4 = 2
    ACTION_MODIFIER_ALL = 4

    ACTIONS = [
      { :action => ACTION_PAINT_PARTS, :modifiers => [ACTION_MODIFIER_1, ACTION_MODIFIER_ALL ] },
      { :action => ACTION_PAINT_EDGES, :modifiers => [ACTION_MODIFIER_1, ACTION_MODIFIER_2, ACTION_MODIFIER_4 ] },
      { :action => ACTION_PAINT_FACES, :modifiers => [ACTION_MODIFIER_1, ACTION_MODIFIER_2 ] },
      { :action => ACTION_PICK },
      { :action => ACTION_PAINT_CLEAN }
    ].freeze

    COLOR_MATERIAL_TYPES = {
      MaterialAttributes::TYPE_UNKNOWN => Sketchup::Color.new(128, 128, 128).freeze,
      MaterialAttributes::TYPE_SOLID_WOOD => Sketchup::Color.new(76, 175, 80).freeze,
      MaterialAttributes::TYPE_SHEET_GOOD => Sketchup::Color.new(237, 162, 0).freeze,
      MaterialAttributes::TYPE_DIMENSIONAL => Sketchup::Color.new(245, 89, 172).freeze,
      MaterialAttributes::TYPE_HARDWARE => Sketchup::Color.new(0, 0, 0).freeze,
      MaterialAttributes::TYPE_EDGE => Sketchup::Color.new(102, 142, 238).freeze,
      MaterialAttributes::TYPE_VENEER => Sketchup::Color.new(131, 56, 236).freeze
    }

    @@action = nil
    @@action_modifiers = {} # { action => MODIFIER }

    @@action_materials = {} # { action => Sketchup::Material }
    @@action_filters = {}   # { action => Array<MaterialAttributes:TYPE> }

    @@filters = nil

    def initialize(material = nil)
      super(true, false)

      # Keep the given material
      @startup_material = material

      # Setup default filter if not set
      if @@filters.nil?
        @@filters = {}
        for type in 0..COLOR_MATERIAL_TYPES.length - 1
          @@filters[type] = true
        end
      end

      # Create cursors
      @cursor_paint_part_id = create_cursor('paint-part', 2, 15)
      @cursor_paint_edge_1_id = create_cursor('paint-edge-1', 2, 15)
      @cursor_paint_edge_2_id = create_cursor('paint-edge-2', 2, 15)
      @cursor_paint_edge_4_id = create_cursor('paint-edge-4', 2, 15)
      @cursor_paint_face_1_id = create_cursor('paint-face-1', 2, 15)
      @cursor_paint_face_2_id = create_cursor('paint-face-2', 2, 15)
      @cursor_paint_clean_id = create_cursor('paint-clean', 2, 15)
      @cursor_picker_id = create_cursor('picker', 3, 29)
      @cursor_paint_error_id = create_cursor('paint-error', 2, 15)

    end

    def get_stripped_name
      'paint'
    end

    def setup_entities(view)
      super

      # Materials panel

      @materials_panel = Kuix::Panel.new
      @materials_panel.layout_data = Kuix::StaticLayoutData.new(0, 1.0, 1.0, -1, Kuix::Anchor.new(Kuix::Anchor::BOTTOM_LEFT))
      @materials_panel.layout = Kuix::BorderLayout.new
      @canvas.append(@materials_panel)

      # Material Infos panel

      @material_infos_panel = Kuix::Panel.new
      @material_infos_panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::NORTH)
      @material_infos_panel.layout = Kuix::InlineLayout.new(true, @unit, Kuix::Anchor.new(Kuix::Anchor::CENTER))
      @material_infos_panel.padding.set_all!(@unit * 2)
      @material_infos_panel.visible = false
      @material_infos_panel.set_style_attribute(:background_color, Sketchup::Color.new(255, 255, 255, 85))
      @materials_panel.append(@material_infos_panel)

        @material_infos_lbl_1 = Kuix::Label.new
        @material_infos_lbl_1.text_size = @unit * 3 * get_text_unit_factor
        @material_infos_lbl_1.text_bold = true
        @material_infos_panel.append(@material_infos_lbl_1)

        @material_infos_lbl_2 = Kuix::Label.new
        @material_infos_lbl_2.text_size = @unit * 3 * get_text_unit_factor
        @material_infos_panel.append(@material_infos_lbl_2)

      # Materials Add button

      @materials_add_btn = Kuix::Button.new
      @materials_add_btn.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::WEST)
      @materials_add_btn.layout = Kuix::StaticLayout.new
      @materials_add_btn.min_size.set!(@unit * 8, @unit * 8)
      @materials_add_btn.set_style_attribute(:background_color, COLOR_BRAND_DARK)
      @materials_add_btn.set_style_attribute(:background_color, COLOR_BRAND_LIGHT, :hover)
      @materials_add_btn.set_style_attribute(:background_color, COLOR_BRAND_LIGHT, :active)
      @materials_add_btn.on(:click) { |button|
        Plugin.instance.execute_dialog_command_on_tab('materials', 'new_material')
      }
      @materials_panel.append(@materials_add_btn)

        motif = Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0.5L0.5,0.5L0.5,0L0.5,0.5L1,0.5L0.5,0.5L0.5,1'))
        motif.layout_data = Kuix::StaticLayoutData.new(0.5, 0, @unit * 10, @unit * 10, Kuix::Anchor.new(Kuix::Anchor::TOP_CENTER))
        motif.padding.set_all!(@unit * 2)
        motif.line_width = @unit <= 4 ? 1 : 2
        motif.set_style_attribute(:color, COLOR_BRAND_LIGHT)
        motif.set_style_attribute(:color, COLOR_BRAND_DARK, :hover)
        @materials_add_btn.append(motif)

      # Materials Filters button

      @materials_filters_btn = Kuix::Button.new
      @materials_filters_btn.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::EAST)
      @materials_filters_btn.layout = Kuix::StaticLayout.new
      @materials_filters_btn.min_size.set!(@unit * 8, @unit * 8)
      @materials_filters_btn.set_style_attribute(:background_color, COLOR_BRAND_DARK)
      @materials_filters_btn.set_style_attribute(:background_color, COLOR_BRAND_LIGHT, :hover)
      @materials_filters_btn.set_style_attribute(:background_color, COLOR_BRAND_LIGHT, :active)
      @materials_filters_btn.set_style_attribute(:background_color, COLOR_BRAND, :selected)
      @materials_filters_btn.on(:click) { |button|
        @materials_filters_panel.visible = !@materials_filters_panel.visible?
        button.selected = @materials_filters_panel.visible?
      }
      @materials_panel.append(@materials_filters_btn)

        panel = Kuix::Panel.new
        panel.layout_data = Kuix::StaticLayoutData.new(0.5, 0, 0, @unit * 10, Kuix::Anchor.new(Kuix::Anchor::TOP_CENTER))
        panel.layout = Kuix::InlineLayout.new
        @materials_filters_btn.append(panel)

          motif = Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.4,1L0.4,0.5L0.1,0.2L0.1,0L0.9,0L0.9,0.2L0.6,0.5L0.6,0.9L0.4,1'))
          motif.padding.set_all!(@unit * 2)
          motif.min_size.set_all!(@unit * 6)
          motif.line_width = @unit <= 4 ? 1 : 2
          motif.set_style_attribute(:color, COLOR_BRAND_LIGHT)
          motif.set_style_attribute(:color, COLOR_BRAND_DARK, :hover)
          motif.set_style_attribute(:color, COLOR_WHITE, :selected)
          panel.append(motif)

          @materials_filters_btn_lbl = Kuix::Label.new('glop')
          @materials_filters_btn_lbl.padding.set!(0, @unit * 2, 0, 0)
          @materials_filters_btn_lbl.text_size = @unit * 3
          @materials_filters_btn_lbl.visible = false
          @materials_filters_btn_lbl.set_style_attribute(:color, COLOR_BRAND_LIGHT)
          @materials_filters_btn_lbl.set_style_attribute(:color, COLOR_BRAND_DARK, :hover)
          @materials_filters_btn_lbl.set_style_attribute(:color, COLOR_WHITE, :selected)
          panel.append(@materials_filters_btn_lbl)

      # Materials Buttons panel

      @materials_btns_panel = Kuix::Panel.new
      @materials_btns_panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::CENTER)
      @materials_btns_panel.set_style_attribute(:background_color, COLOR_BRAND_DARK)
      @materials_panel.append(@materials_btns_panel)

      # Materials Filters panel

      @materials_filters_panel = Kuix::Panel.new
      @materials_filters_panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::SOUTH)
      @materials_filters_panel.layout = Kuix::BorderLayout.new
      @materials_filters_panel.padding.set_all!(@unit * 2)
      @materials_filters_panel.set_style_attribute(:background_color, COLOR_WHITE)
      @materials_filters_panel.visible = false
      @materials_panel.append(@materials_filters_panel)

        lbl = Kuix::Label.new
        lbl.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::WEST)
        lbl.padding.set!(0, @unit * 3, 0, @unit * 3)
        lbl.text = Plugin.instance.get_i18n_string('tool.smart_paint.filters').upcase
        lbl.text_size = @unit * 3 * get_text_unit_factor
        lbl.text_bold = true
        @materials_filters_panel.append(lbl)

        panel = Kuix::Panel.new
        panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::CENTER)
        panel.layout = Kuix::GridLayout.new(COLOR_MATERIAL_TYPES.length,1, @unit, @unit)
        @materials_filters_panel.append(panel)

        @materials_filters_btns = []
        COLOR_MATERIAL_TYPES.each do |type, color|

          btn = Kuix::Button.new
          btn.min_size.set_all!(@unit * 6)
          btn.border.set_all!(@unit / 2)
          btn.set_style_attribute(:background_color, COLOR_LIGHT_GREY)
          btn.set_style_attribute(:background_color, color, :active)
          btn.set_style_attribute(:background_color, COLOR_WHITE, :selected)
          btn.set_style_attribute(:background_color, color.blend(COLOR_WHITE, 0.2), :hover)
          btn.set_style_attribute(:background_color, COLOR_DARK_GREY.blend(COLOR_WHITE, 0.1), :disabled)
          btn.set_style_attribute(:border_color, color, :selected)
          btn.selected = @@filters[type]
          btn.data = type
          lbl = btn.append_static_label(Plugin.instance.get_i18n_string("tool.smart_paint.filter_#{type}"), @unit * 3 * get_text_unit_factor)
          lbl.set_style_attribute(:color, COLOR_DARK_GREY, :disabled)
          btn.on(:click) { |button|

            unless get_enabled_filters_by_action(fetch_action).index(button.data).nil?

              toggle_filter_by_type(button.data)
              update_filters_ratio

              store_action_filters(fetch_action, @@filters.clone)

              # Re populate material defs & setup corresponding buttons
              _populate_material_defs(view.model)
              _setup_material_buttons

            end

          }
          btn.on(:doubleclick) { |button|

            unless get_enabled_filters_by_action(fetch_action).index(button.data).nil?

              set_filters(false)
              set_filter_by_type(button.data, true)
              update_filters_ratio

              # Re populate material defs & setup corresponding buttons
              _populate_material_defs(view.model)
              _setup_material_buttons

            end

          }
          panel.append(btn)

          @materials_filters_btns.push(btn)

        end

    end

    # -- Show --

    def notify_material_infos(material, material_attributes)
      return if material.nil? || material_attributes.nil?

      text_1 = material.display_name
      text_2 = material_attributes.type > MaterialAttributes::TYPE_UNKNOWN ? "(#{Plugin.instance.get_i18n_string("tab.materials.type_#{material_attributes.type}")})" : ''

      return unless @material_infos_panel && text_1.is_a?(String) && text_2.is_a?(String)
      @material_infos_lbl_1.text = text_1
      @material_infos_lbl_1.visible = !text_1.empty?
      @material_infos_lbl_2.text = text_2
      @material_infos_lbl_2.visible = !text_2.empty?
      @material_infos_panel.visible = @material_infos_lbl_1.visible? || @material_infos_lbl_2.visible?
    end

    def hide_material_infos
      @material_infos_panel.visible = false
    end

    # -- Actions --

    def get_action_defs  # Array<{ :action => THE_ACTION, :modifiers => [ MODIFIER_1, MODIFIER_2, ... ] }>
      ACTIONS
    end

    def get_action_status(action)

      case action
      when ACTION_PAINT_PARTS
        return super +
          ' | ↑↓ + ' + Plugin.instance.get_i18n_string('tool.default.transparency') + ' = ' + Plugin.instance.get_i18n_string('tool.default.toggle_depth') + '.' +
          ' | ' + Plugin.instance.get_i18n_string("default.tab_key") + ' = ' + Plugin.instance.get_i18n_string('tool.smart_paint.action_1') + '.' +
          ' | ' + Plugin.instance.get_i18n_string("default.alt_key_#{Plugin.instance.platform_name}") + ' = ' + Plugin.instance.get_i18n_string('tool.smart_paint.action_3') + '.'
      when ACTION_PAINT_EDGES
        return super +
          ' | ' + Plugin.instance.get_i18n_string("default.tab_key") + ' = ' + Plugin.instance.get_i18n_string('tool.smart_paint.action_2') + '.' +
          ' | ' + Plugin.instance.get_i18n_string("default.alt_key_#{Plugin.instance.platform_name}") + ' = ' + Plugin.instance.get_i18n_string('tool.smart_paint.action_3') + '.'
      when ACTION_PAINT_FACES
        return super +
          ' | ' + Plugin.instance.get_i18n_string("default.tab_key") + ' = ' + Plugin.instance.get_i18n_string('tool.smart_paint.action_3') + '.' +
          ' | ' + Plugin.instance.get_i18n_string("default.alt_key_#{Plugin.instance.platform_name}") + ' = ' + Plugin.instance.get_i18n_string('tool.smart_paint.action_3') + '.'
      when ACTION_PICK
        return super +
          ' | ' + Plugin.instance.get_i18n_string("default.tab_key") + ' = ' + Plugin.instance.get_i18n_string('tool.smart_paint.action_0') + '.'
      when ACTION_PAINT_CLEAN
        return super +
          ' | ↑↓ + ' + Plugin.instance.get_i18n_string('tool.default.transparency') + ' = ' + Plugin.instance.get_i18n_string('tool.default.toggle_depth') + '.' +
          ' | ' + Plugin.instance.get_i18n_string("default.tab_key") + ' = ' + Plugin.instance.get_i18n_string('tool.smart_paint.action_0') + '.' +
          ' | ' + Plugin.instance.get_i18n_string("default.alt_key_#{Plugin.instance.platform_name}") + ' = ' + Plugin.instance.get_i18n_string('tool.smart_paint.action_3') + '.'
      end

      super
    end

    def get_action_cursor(action, modifier)

      # Update status text and root cursor
      case action
      when ACTION_PAINT_PARTS
        return @cursor_paint_part_id
      when ACTION_PAINT_EDGES
        case modifier
        when ACTION_MODIFIER_4
          return @cursor_paint_edge_4_id
        when ACTION_MODIFIER_2
          return @cursor_paint_edge_2_id
        when ACTION_MODIFIER_1
          return @cursor_paint_edge_1_id
        end
      when ACTION_PAINT_FACES
        case modifier
        when ACTION_MODIFIER_2
          return @cursor_paint_face_2_id
        when ACTION_MODIFIER_1
          return @cursor_paint_face_1_id
        end
      when ACTION_PICK
        return @cursor_picker_id
      when ACTION_PAINT_CLEAN
        return @cursor_paint_clean_id
      else
        return @cursor_paint_error_id
      end

      super
    end

    def get_action_modifier_btn_child(action, modifier)

      case action
      when ACTION_PAINT_PARTS
        case modifier
        when ACTION_MODIFIER_1
          lbl = Kuix::Label.new
          lbl.text = '1'
          return lbl
        when ACTION_MODIFIER_ALL
          lbl = Kuix::Label.new
          lbl.text = '∞'
          return lbl
        end
      when ACTION_PAINT_EDGES
        case modifier
        when ACTION_MODIFIER_1
          lbl = Kuix::Label.new
          lbl.text = '1'
          return lbl
        when ACTION_MODIFIER_2
          lbl = Kuix::Label.new
          lbl.text = '2'
          return lbl
        when ACTION_MODIFIER_4
          lbl = Kuix::Label.new
          lbl.text = '4'
          return lbl
        end
      when ACTION_PAINT_FACES
        case modifier
        when ACTION_MODIFIER_1
          lbl = Kuix::Label.new
          lbl.text = '1'
          return lbl
        when ACTION_MODIFIER_2
          lbl = Kuix::Label.new
          lbl.text = '2'
          return lbl
        end
      end

      super
    end

    def store_action(action)
      @@action = action
    end

    def fetch_action
      @@action
    end

    def store_action_modifier(action, modifier)
      @@action_modifiers[action] = modifier
    end

    def fetch_action_modifier(action)
      @@action_modifiers[action]
    end

    def store_action_material(action, material)
      @@action_materials[action] = material
    end

    def fetch_action_material(action)
      @@action_materials[action]
    end

    def store_action_filters(action, filters)
      @@action_filters[action] = filters
    end

    def fetch_action_filters(action)
      @@action_filters[action]
    end

    def get_startup_action
      return super if @startup_material.nil?

      case MaterialAttributes.new(@startup_material).type
      when MaterialAttributes::TYPE_EDGE
        startup_action = ACTION_PAINT_EDGES
      when MaterialAttributes::TYPE_VENEER
        startup_action = ACTION_PAINT_FACES
      else
        startup_action = ACTION_PAINT_PARTS
      end
      store_action_material(startup_action, @startup_material)
      startup_action

    end

    def is_action_part?
      is_action_paint_parts? || is_action_paint_edges? || is_action_paint_faces? || is_action_paint_clean?
    end

    def is_action_paint_parts?
      fetch_action == ACTION_PAINT_PARTS
    end

    def is_action_paint_edges?
      fetch_action == ACTION_PAINT_EDGES
    end

    def is_action_paint_faces?
      fetch_action == ACTION_PAINT_FACES
    end

    def is_action_pick?
      fetch_action == ACTION_PICK
    end

    def is_action_paint_clean?
      fetch_action == ACTION_PAINT_CLEAN
    end

    def is_action_modifier_1?
      fetch_action_modifier(fetch_action) == ACTION_MODIFIER_1
    end

    def is_action_modifier_2?
      fetch_action_modifier(fetch_action) == ACTION_MODIFIER_2
    end

    def is_action_modifier_4?
      fetch_action_modifier(fetch_action) == ACTION_MODIFIER_4
    end

    def is_action_modifier_all?
      fetch_action_modifier(fetch_action) == ACTION_MODIFIER_ALL
    end

    # -- Filters --

    def get_enabled_filters_by_action(action)

      case action
      when ACTION_PAINT_PARTS
        [
          MaterialAttributes::TYPE_UNKNOWN,
          MaterialAttributes::TYPE_SOLID_WOOD,
          MaterialAttributes::TYPE_SHEET_GOOD,
          MaterialAttributes::TYPE_DIMENSIONAL,
          MaterialAttributes::TYPE_HARDWARE,
        ]
      when ACTION_PAINT_EDGES
        [
          MaterialAttributes::TYPE_EDGE
        ]
      when ACTION_PAINT_FACES
        [
          MaterialAttributes::TYPE_VENEER
        ]
      else
        [
          MaterialAttributes::TYPE_UNKNOWN,
          MaterialAttributes::TYPE_SOLID_WOOD,
          MaterialAttributes::TYPE_SHEET_GOOD,
          MaterialAttributes::TYPE_DIMENSIONAL,
          MaterialAttributes::TYPE_HARDWARE,
          MaterialAttributes::TYPE_EDGE,
          MaterialAttributes::TYPE_VENEER
        ]
      end

    end

    def set_filters(value = true, property = :selected)

      @@filters.keys.each do |type|
        set_filter_by_type(type, value, property)
      end

    end

    def set_filter_by_type(type, value, property = :selected)

      @@filters[type] = value if property == :selected

      if @materials_filters_btns
        @materials_filters_btns.each { |button|
          if button.data == type
            case property
            when :selected
              button.selected = value
            when :disabled
              button.disabled = value
            end
          end
        }
      end

    end

    def toggle_filter_by_type(type, property = :selected)
      set_filter_by_type(type, !@@filters[type], property)
    end

    def update_filters_ratio

      enabled_filters = get_enabled_filters_by_action(fetch_action)
      selected_filter_count = 0
      enabled_filters.each do |type|
        selected_filter_count += 1 if @@filters[type]
      end

      @materials_filters_btn_lbl.text = "#{selected_filter_count}/#{enabled_filters.length}"
      @materials_filters_btn_lbl.visible = selected_filter_count < enabled_filters.length

    end

    def set_current_material(material, update_buttons = false, update_action = false)

      # Switch action according to material type
      if update_action
        case MaterialAttributes.new(material).type
        when MaterialAttributes::TYPE_EDGE
          set_root_action(ACTION_PAINT_EDGES)
        when MaterialAttributes::TYPE_VENEER
          set_root_action(ACTION_PAINT_FACES)
        else
          set_root_action(ACTION_PAINT_PARTS)
        end
      end

      # Save material as current
      store_action_material(fetch_action, material)

      # Update buttons
      if update_buttons
        @material_buttons.each { |button|
          button.selected = button.data == material
        }
      end

    end

    def get_current_material
      material = fetch_action_material(fetch_action)
      return material if material
      nil
    end

    # -- Events --

    def onActivate(view)
      super

      # Force global current material to be valid
      unless get_current_material.nil?
        begin
          get_current_material.model == Sketchup.active_model
        rescue => e # Reference to deleted Entity
          store_action_material(fetch_action, nil)
        end
      end

      # Observe model events
      view.model.add_observer(self)

      # Observe materials events
      view.model.materials.add_observer(self)

    end

    def onDeactivate(view)
      super

      # Stop observing model events
      view.model.remove_observer(self)

      # Stop observing materials events
      view.model.materials.remove_observer(self)

    end

    def onActionChange(action, modifier)

      if is_action_pick? || is_action_paint_clean?

        @materials_panel.visible = false

      else

        @materials_panel.visible = true

        # Auto filter
        action_filters = fetch_action_filters(action)
        enabled_filters = get_enabled_filters_by_action(action)
        set_filters(false, :selected)
        set_filters(true, :disabled)
        enabled_filters.each do |type|
          set_filter_by_type(type, action_filters.nil? || action_filters[type].nil? ? true : action_filters[type], :selected)
          set_filter_by_type(type, false, :disabled)
        end
        update_filters_ratio

        # Re populate material defs & setup corresponding buttons
        _populate_material_defs(Sketchup.active_model)
        _setup_material_buttons

      end

      # Simulate mouse move event
      _handle_mouse_event(:move)

    end

    def onKeyDown(key, repeat, flags, view)
      return true if super
      if key == VK_LEFT
        button = _get_selected_material_button
        if button && button.previous && button.previous.is_a?(Kuix::Button)
          button.previous.fire(:click, flags)
          return true
        end
      elsif key == VK_RIGHT
        button = _get_selected_material_button
        if button && button.next && button.next.is_a?(Kuix::Button)
          button.next.fire(:click, flags)
          return true
        end
      elsif key == ALT_MODIFIER_KEY
        unless is_action_pick?
          push_action(ACTION_PICK)
        end
        return true
      elsif repeat == 1
        if key == VK_ADD && is_action_part?
          @materials_add_btn.fire(:click, flags) if @materials_add_btn
          return true
        end
      end
    end

    def onKeyUpExtended(key, repeat, flags, view, after_down, is_quick)
      return true if super
      if key == ALT_MODIFIER_KEY
        if is_action_pick?
          pop_action
        end
        return true
      end
    end

    def onLButtonDown(flags, x, y, view)
      return true if super
      unless is_action_none?
        _handle_mouse_event(:l_button_down)
      end
    end

    def onLButtonUp(flags, x, y, view)
      return true if super
      unless is_action_none?
        _handle_mouse_event(:l_button_up)
      end
    end

    def onMouseMove(flags, x, y, view)
      return true if super
      unless is_action_none?
        _handle_mouse_event(:move)
      end
    end

    def onMouseLeave(view)
      return true if super
      _reset_active_part
    end

    def onTransactionUndo(model)
      _refresh_active_part
    end

    def onMaterialAdd(materials, material)
      _populate_material_defs(Sketchup.active_model)
      _setup_material_buttons
      set_current_material(material, true, true)
    end

    def onMaterialRemove(materials, material)
      begin
        if material == get_current_material
          store_action_material(fetch_action, nil)
        end
      rescue => e # Reference to deleted Entity
        store_action_material(fetch_action, nil)
      end
      _populate_material_defs(Sketchup.active_model)
      _setup_material_buttons
    end

    def onMaterialChange(materials, material)
      _populate_material_defs(Sketchup.active_model)
      _setup_material_buttons
    end

    # -----

    protected

    def _set_active_part(part_entity_path, part, highlighted = false)
      super

      @active_instances = []
      @active_faces = []
      @active_material = nil

      if part

        model = Sketchup.active_model

        if is_action_paint_parts?

          # Show part infos
          notify_infos(part.name)

          @active_material = get_current_material
          color = @active_material ? @active_material.color : MaterialUtils::get_color_from_path(@active_part_entity_path[0...-1]) # [0...-1] returns array without last element
          color.alpha = highlighted ? 255 : 200

          active_instance = @active_part_entity_path.last
          instances = is_action_modifier_all? ? active_instance.definition.instances : [ active_instance ]
          instance_paths = []
          _instances_to_paths(instances, instance_paths, model.active_entities, model.active_path ? model.active_path : [])

          triangles = _compute_children_faces_triangles(active_instance.definition.entities)

          instance_paths.each do |path|

            mesh = Kuix::Mesh.new
            mesh.add_triangles(triangles)
            mesh.background_color = color
            mesh.transformation = PathUtils::get_transformation(path)
            @space.append(mesh)

          end

          if is_action_modifier_all?
            definition = Sketchup.active_model.definitions[part.def.definition_id]
            if definition && definition.count_used_instances > 1
              notify_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_axes.warning.more_entities', { :count_used => definition.count_used_instances })}", MESSAGE_TYPE_WARNING)
            end
          end

          @active_instances = instances

        elsif is_action_paint_edges?

          if part.group.material_type != MaterialAttributes::TYPE_SHEET_GOOD
            notify_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_paint.error.wrong_material_type', { :type => Plugin.instance.get_i18n_string("tab.materials.type_#{MaterialAttributes::TYPE_SHEET_GOOD}") })}", MESSAGE_TYPE_ERROR)
            push_cursor(@cursor_paint_error_id)
          else

            edge_faces = {}
            part.def.edge_entity_ids.each { |k, v| edge_faces[k] = model.find_entity_by_id(v) if v.is_a?(Array) && !v.empty? }

            sides = []
            faces = []
            if is_action_modifier_1? || is_action_modifier_2?

              picked_side = nil
              edge_faces.each { |k, v|
                v.each { |face|
                  if face == @input_face # picked_face
                    picked_side = k
                    break
                  end
                }
                break unless picked_side.nil?
              }

              if picked_side
                sides << picked_side unless edge_faces[picked_side].nil?
                if is_action_modifier_2?
                  sides << :ymin if picked_side == :ymax && !edge_faces[:ymin].nil?
                  sides << :ymax if picked_side == :ymin && !edge_faces[:ymax].nil?
                  sides << :xmin if picked_side == :xmax && !edge_faces[:xmin].nil?
                  sides << :xmax if picked_side == :xmin && !edge_faces[:xmax].nil?
                end
              end

            elsif is_action_modifier_4?
              sides << :ymin unless edge_faces[:ymin].nil?
              sides << :ymax unless edge_faces[:ymax].nil?
              sides << :xmin unless edge_faces[:xmin].nil?
              sides << :xmax unless edge_faces[:xmax].nil?
            end

            sides.each { |side|
              faces << edge_faces[side]
            }
            faces = faces.flatten

            if faces.empty?
              notify_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_paint.error.not_edge')}", MESSAGE_TYPE_ERROR)
              push_cursor(@cursor_paint_error_id)
            else

              # Show edges infos
              notify_infos(part.name, [ Plugin.instance.get_i18n_string('tool.smart_paint.edges', { :count => sides.length }) + (sides.length < 4 ? " → #{sides.map { |side| Plugin.instance.get_i18n_string("tool.smart_paint.edge_#{side}") }.join(' + ')}" : '') ])

              @active_material = get_current_material
              color = @active_material ? @active_material.color : MaterialUtils::get_color_from_path(@active_part_entity_path)
              color.alpha = highlighted ? 255 : 200

              active_instance = @active_part_entity_path.last
              instances = active_instance.definition.instances
              instance_paths = []
              _instances_to_paths(instances, instance_paths, model.active_entities, model.active_path ? model.active_path : [])

              triangles = _compute_children_faces_triangles(active_instance.definition.entities, nil, faces)

              instance_paths.each do |path|

                mesh = Kuix::Mesh.new
                mesh.add_triangles(triangles)
                mesh.background_color = color
                mesh.transformation = PathUtils::get_transformation(path)
                @space.append(mesh)

              end

              definition = Sketchup.active_model.definitions[part.def.definition_id]
              if definition && definition.count_used_instances > 1
                notify_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_axes.warning.more_entities', { :count_used => definition.count_used_instances })}", MESSAGE_TYPE_WARNING)
              end

              @active_instances = instances
              @active_faces = faces

            end

          end

        elsif is_action_paint_faces?

          if part.group.material_type != MaterialAttributes::TYPE_SHEET_GOOD
            notify_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_paint.error.wrong_material_type', { :type => Plugin.instance.get_i18n_string("tab.materials.type_#{MaterialAttributes::TYPE_SHEET_GOOD}") })}", MESSAGE_TYPE_ERROR)
            push_cursor(@cursor_paint_error_id)
          else

            face_faces = {}
            part.def.face_entity_ids.each { |k, v| face_faces[k] = model.find_entity_by_id(v) if v.is_a?(Array) && !v.empty? }

            sides = []
            faces = []
            if is_action_modifier_1?

              picked_side = nil
              face_faces.each { |k, v|
                v.each { |face|
                  if face == @input_face # picked_face
                    picked_side = k
                    break
                  end
                }
                break unless picked_side.nil?
              }

              if picked_side
                sides << picked_side unless face_faces[picked_side].nil?
              end

            elsif is_action_modifier_2?
              sides << :zmax unless face_faces[:zmax].nil?
              sides << :zmin unless face_faces[:zmin].nil?
            end

            sides.each { |side|
              faces << face_faces[side]
            }
            faces = faces.flatten

            if faces.empty?
              notify_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_paint.error.not_face')}", MESSAGE_TYPE_ERROR)
              push_cursor(@cursor_paint_error_id)
            else

              # Show faces infos
              notify_infos(part.name, [ "#{Plugin.instance.get_i18n_string('tool.smart_paint.faces', { :count => sides.length })} → #{sides.map { |side| Plugin.instance.get_i18n_string("tool.smart_paint.face_#{side}") }.join(' + ')}" ])

              @active_material = get_current_material
              color = @active_material ? @active_material.color : MaterialUtils::get_color_from_path(@active_part_entity_path)
              color.alpha = highlighted ? 255 : 200

              active_instance = @active_part_entity_path.last
              instances = active_instance.definition.instances
              instance_paths = []
              _instances_to_paths(instances, instance_paths, model.active_entities, model.active_path ? model.active_path : [])

              triangles = _compute_children_faces_triangles(active_instance.definition.entities, nil, faces)

              instance_paths.each do |path|

                mesh = Kuix::Mesh.new
                mesh.add_triangles(triangles)
                mesh.background_color = color
                mesh.transformation = PathUtils::get_transformation(path)
                @space.append(mesh)

              end

              definition = Sketchup.active_model.definitions[part.def.definition_id]
              if definition && definition.count_used_instances > 1
                notify_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_axes.warning.more_entities', { :count_used => definition.count_used_instances })}", MESSAGE_TYPE_WARNING)
              end

              @active_instances = instances
              @active_faces = faces

            end

          end

        elsif is_action_paint_clean?

          # Show part infos
          notify_infos(part.name)

          color = MaterialUtils::get_color_from_path(@active_part_entity_path[0...-1]) # [0...-1] returns array without last element
          color.alpha = highlighted ? 255 : 200

          active_instance = @active_part_entity_path.last
          instances = active_instance.definition.instances
          instance_paths = []
          _instances_to_paths(instances, instance_paths, model.active_entities, model.active_path ? model.active_path : [])

          triangles = _compute_children_faces_triangles(active_instance.definition.entities)

          instance_paths.each do |path|

            mesh = Kuix::Mesh.new
            mesh.add_triangles(triangles)
            mesh.background_color = color
            mesh.transformation = PathUtils::get_transformation(path)
            @space.append(mesh)

          end

          definition = model.definitions[part.def.definition_id]
          if definition && definition.count_used_instances > 1
            notify_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_axes.warning.more_entities', { :count_used => definition.count_used_instances })}", MESSAGE_TYPE_WARNING)
          end

          @active_instances = instances

        end

      end

    end

    def _can_pick_deeper?
      super && !is_action_paint_edges? && !is_action_paint_faces? && !is_action_pick?
    end

    def _reset_ui
      super

      # Hide previous overlays
      hide_material_infos

    end

    # -----

    private

    def _populate_material_defs(model)

      # Build the material defs
      @material_defs = []
      current_material_exists = false
      model.materials.each do |material|
        material_attributes = MaterialAttributes.new(material)
        if @@filters[material_attributes.type]
          @material_defs.push({
                                :material => material,
                                :material_attributes => material_attributes
                              })
        end
        current_material_exists = current_material_exists || get_current_material.object_id == material.object_id
      end

      # Sort material defs (type > name)
      @material_defs.sort_by! { |material_def| [ MaterialAttributes::type_order(material_def[:material_attributes].type), material_def[:material].display_name ] }

      # Select default current material if necessary
      if model.materials.length == 0 || fetch_action_material(fetch_action) == false
        set_current_material(false)
      elsif !@material_defs.empty? && (!current_material_exists || fetch_action_material(fetch_action).nil?)
        set_current_material(@material_defs.first[:material])
      end

    end

    def _setup_material_buttons

      @materials_btns_panel.remove_all
      @materials_btns_panel.layout = Kuix::GridLayout.new([[@material_defs.length + 1, 5 ].max, 10 ].min, ((@material_defs.length + 1) / 10.0).ceil)

      @material_buttons = []

      btn = NoneButton.new
      btn.layout = Kuix::StaticLayout.new
      btn.min_size.set!(@unit * 20, @unit * 8)
      btn.border.set_all!(@unit)
      btn.set_style_attribute(:background_color, COLOR_WHITE)
      btn.set_style_attribute(:background_color, COLOR_WHITE.blend(COLOR_BLACK, 0.7), :active)
      btn.set_style_attribute(:border_color, COLOR_WHITE)
      btn.set_style_attribute(:border_color, COLOR_WHITE.blend(COLOR_BLACK, 0.8), :hover)
      btn.set_style_attribute(:border_color, COLOR_BRAND, :selected)
      btn.append_static_label(Plugin.instance.get_i18n_string('tool.smart_paint.default_material'), @unit * 3 * get_text_unit_factor)
      btn.data = false  # = No material
      btn.selected = get_current_material.nil?
      btn.on(:click) { |button|

        # Set material as current
        set_current_material(false, true)

      }
      @materials_btns_panel.append(btn)
      @material_buttons.push(btn)

      if @material_defs.empty?

        lbl = Kuix::Label.new
        lbl.layout_data = Kuix::GridLayoutData.new(3)
        lbl.text_size = @unit * 3 * get_text_unit_factor
        if is_action_paint_parts?
          lbl.text = Plugin.instance.get_i18n_string('tool.smart_paint.warning.no_material')
        elsif is_action_paint_edges?
          lbl.text = Plugin.instance.get_i18n_string('tool.smart_paint.warning.no_material_type', { :type => Plugin.instance.get_i18n_string("tab.materials.type_#{MaterialAttributes::TYPE_EDGE}") })
        elsif is_action_paint_faces?
          lbl.text = Plugin.instance.get_i18n_string('tool.smart_paint.warning.no_material_type', { :type => Plugin.instance.get_i18n_string("tab.materials.type_#{MaterialAttributes::TYPE_VENEER}") })
        end
        lbl.set_style_attribute(:color, COLOR_BRAND_LIGHT)
        @materials_btns_panel.append(lbl)

      end

      @material_defs.each do |material_def|

        material = material_def[:material]
        material_attributes = material_def[:material_attributes]
        material_color = material.color
        material_color.alpha = 255
        material_color_is_dark = ColorUtils::color_is_dark?(material_color)

        btn = Kuix::Button.new
        btn.layout = Kuix::StaticLayout.new
        btn.min_size.set!(@unit * 20, @unit * 8)
        btn.border.set_all!(@unit)
        btn.set_style_attribute(:background_color, material_color)
        btn.set_style_attribute(:background_color, material_color.blend(material_color_is_dark ? COLOR_WHITE : COLOR_BLACK, 0.7), :active)
        btn.set_style_attribute(:border_color, material_color)
        btn.set_style_attribute(:border_color, material_color.blend(material_color_is_dark ? COLOR_WHITE : COLOR_BLACK, 0.7), :hover)
        btn.set_style_attribute(:border_color, COLOR_BRAND, :selected)
        btn.append_static_label(material.display_name, @unit * 3 * get_text_unit_factor, material_color_is_dark ? COLOR_WHITE : nil)
        btn.data = material
        btn.selected = material == get_current_material
        btn.on(:click) { |button|

          # Set material as current
          set_current_material(material, true)

        }
        btn.on(:doubleclick) { |button|

          # Edit material
          Plugin.instance.execute_dialog_command_on_tab('materials', 'edit_material', "{ materialId: #{material.entityID} }")

        }
        btn.on(:enter) { |button|
          notify_material_infos(material, material_attributes)
        }
        btn.on(:leave) { |button|
          hide_material_infos
        }
        @materials_btns_panel.append(btn)
        @material_buttons.push(btn)

        if material_attributes.type > MaterialAttributes::TYPE_UNKNOWN

          btn_overlay = Kuix::Panel.new
          btn_overlay.layout_data = Kuix::StaticLayoutData.new(1.0, 0, @unit * 2, @unit * 2, Kuix::Anchor.new(Kuix::Anchor::TOP_RIGHT))
          btn_overlay.set_style_attribute(:background_color, COLOR_MATERIAL_TYPES[material_attributes.type])
          btn_overlay.set_style_attribute(:border_color, COLOR_WHITE)
          btn_overlay.border.set_all!(@unit / 4)
          btn_overlay.hittable = false
          btn.append(btn_overlay)

        end

      end

    end

    def _get_selected_material_button
      @material_buttons.each { |button|
        return button if button.selected?
      }
      nil
    end

    def _handle_mouse_event(event = nil)
      if is_action_part?

        if event == :move

          if @input_face_path
            input_part_entity_path = _get_part_entity_path_from_path(@input_face_path)
            if input_part_entity_path

              part = _generate_part_from_path(input_part_entity_path)
              if part
                _set_active_part(input_part_entity_path, part, event == :l_button_down)
              else
                _reset_active_part
                notify_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_paint.error.not_part')}", MESSAGE_TYPE_ERROR)
                push_cursor(@cursor_paint_error_id)
              end
              return

            else
              _reset_active_part
              notify_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_paint.error.not_part')}", MESSAGE_TYPE_ERROR)
              push_cursor(@cursor_paint_error_id)
              return
            end
          end
          _reset_active_part  # No input

        elsif event == :l_button_down

          _refresh_active_part(true)

        elsif event == :l_button_up || event == :l_button_dblclick

          model = Sketchup.active_model

          if is_action_paint_parts?

            if @active_instances.nil? || @active_instances.empty?
              UI.beep
              return
            end

            # Start undoable model modification operation
            model.start_operation('OCL Paint Parts', true, false, false)

            # Paint instances
            @active_instances.each do |instance|
              instance.material = @active_material
            end

            # Commit model modification operation
            model.commit_operation

            # Refresh active
            _refresh_active_part

          elsif is_action_paint_edges?

            if @active_faces.nil? || @active_faces.empty?
              UI.beep
              return
            end

            # Start undoable model modification operation
            model.start_operation('OCL Paint Edges', true, false, false)

            @active_faces.each { |face| face.material = @active_material }

            # Commit model modification operation
            model.commit_operation

            # Refresh active
            _refresh_active_part

          elsif is_action_paint_faces?

            if @active_faces.nil? || @active_faces.empty?
              UI.beep
              return
            end

            # Start undoable model modification operation
            model.start_operation('OCL Paint Faces', true, false, false)

            @active_faces.each { |face| face.material = @active_material }

            # Commit model modification operation
            model.commit_operation

            # Refresh active
            _refresh_active_part

          elsif is_action_paint_clean?

            if @active_instances.nil? || @active_instances.empty?
              UI.beep
              return
            end

            # Start undoable model modification operation
            model.start_operation('OCL Paint Clean', true, false, false)

            # Clean definition
            _propagate_material(@active_instances.first.definition.entities, nil)

            # Clean instances
            @active_instances.each do |instance|
              instance.material = nil
            end

            # Commit model modification operation
            model.commit_operation

            # Refresh active
            _refresh_active_part

          end

        end

      elsif is_action_pick?

        material = MaterialUtils::get_material_from_path(@input_face_path)
        if @input_face
          if event == :move

            # Refresh UI
            _reset_ui

            # Display material infos
            if material
              notify_infos(material.name, [ Plugin.instance.get_i18n_string("tab.materials.type_#{MaterialAttributes.new(material).type}") ])
            else
              notify_infos(Plugin.instance.get_i18n_string('tool.smart_paint.default_material'))
            end

          elsif event == :l_button_up

            # Set picked material as current
            set_current_material(material.nil? ? false : material, true, true)

          end
        else
          if event == :move
            _reset_ui
          elsif event == :l_button_up
            UI.beep # Feedback for "no material"
          end
        end

      end
    end

    def _propagate_material(entities, material = nil)
      entities.each do |entity|
        next if entity.is_a?(Sketchup::ComponentInstance) && !entity.definition.behavior.cuts_opening? && !entity.definition.behavior.always_face_camera?
        if entity.is_a?(Sketchup::Drawingelement)
          entity.material = material
          if material.nil? && entity.respond_to?(:clear_texture_position)
            entity.clear_texture_position(true) # Clear texture position is possible (entity is a Face and SU 2022+)
          end
        end
        if entity.is_a?(Sketchup::Group)
          _propagate_material(entity.entities, material)
        end
        if entity.is_a?(Sketchup::ComponentInstance)
          _propagate_material(entity.definition.entities, material)
        end
      end
    end

  end

  class NoneButton < Kuix::Button

    def paint_background(graphics)
      super

      width = @bounds.width - @margin.left - @border.left - @margin.right - @border.right
      height = @bounds.height - @margin.top - @border.top - @margin.bottom - @border.bottom

      graphics.draw_triangle(0, 0, 0, height, width, height, @background_color.blend(Sketchup::Color.new(0, 0, 0), 0.9))
    end

  end

end