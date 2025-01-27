module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative '../lib/kuix/kuix'
  require_relative '../helper/layer_visibility_helper'
  require_relative '../helper/face_triangles_helper'
  require_relative '../helper/edge_segments_helper'
  require_relative '../helper/boundingbox_helper'
  require_relative '../helper/entities_helper'
  require_relative '../model/attributes/definition_attributes'
  require_relative '../model/geom/size3d'
  require_relative '../utils/axis_utils'
  require_relative '../utils/transformation_utils'

  class SmartAxesTool < SmartTool

    include LayerVisibilityHelper
    include FaceTrianglesHelper
    include EdgeSegmentsHelper
    include BoundingBoxHelper
    include EntitiesHelper
    include CutlistObserverHelper

    ACTION_FLIP = 0
    ACTION_SWAP_LENGTH_WIDTH = 1
    ACTION_SWAP_FRONT_BACK = 2
    ACTION_ADAPT_AXES = 3

    ACTION_MODIFIER_CLOCKWISE = 0
    ACTION_MODIFIER_ANTICLOCKWIZE = 1
    ACTION_MODIFIER_LENGTH = 2
    ACTION_MODIFIER_WIDTH = 3
    ACTION_MODIFIER_THICKNESS = 4

    ACTIONS = [
      { :action => ACTION_FLIP, :modifiers => [ACTION_MODIFIER_LENGTH, ACTION_MODIFIER_WIDTH, ACTION_MODIFIER_THICKNESS ], :startup_modifier => ACTION_MODIFIER_THICKNESS },
      { :action => ACTION_SWAP_LENGTH_WIDTH, :modifiers => [ ACTION_MODIFIER_ANTICLOCKWIZE, ACTION_MODIFIER_CLOCKWISE ], :startup_modifier => ACTION_MODIFIER_CLOCKWISE },
      { :action => ACTION_SWAP_FRONT_BACK },
      { :action => ACTION_ADAPT_AXES }
    ].freeze

    COLOR_MESH = Sketchup::Color.new(200, 200, 0, 100).freeze
    COLOR_MESH_HIGHLIGHTED = Sketchup::Color.new(200, 200, 0, 200).freeze
    COLOR_ARROW = COLOR_WHITE
    COLOR_ARROW_AUTO_ORIENTED = Sketchup::Color.new(123, 213, 239).freeze
    COLOR_BOX = COLOR_BLUE
    COLOR_ACTION = COLOR_MAGENTA
    COLOR_ACTION_FILL = Sketchup::Color.new(255, 0, 255, 0.2).freeze

    @@action = nil
    @@action_modifiers = {}

    def initialize
      super(true, false)

      # Create cursors
      @cursor_swap_length_width_clockwise = create_cursor('swap-length-width-clockwise', 0, 0)
      @cursor_swap_length_width_anticlockwise = create_cursor('swap-length-width-anticlockwise', 0, 0)
      @cursor_swap_front_back = create_cursor('swap-front-back', 0, 0)
      @cursor_adapt_axes = create_cursor('adapt-axes', 0, 0)
      @cursor_flip = create_cursor('flip', 0, 0)
      @cursor_select_error = create_cursor('select-error', 0, 0)

    end

    def get_stripped_name
      'axes'
    end

    # -- Actions --

    def get_action_defs  # Array<{ :action => THE_ACTION, :modifiers => [ MODIFIER_1, MODIFIER_2, ... ] }>
      ACTIONS
    end

    def get_action_status(action)

      case action
      when ACTION_FLIP
        return super +
          ' | ↑↓ + ' + Plugin.instance.get_i18n_string('tool.default.transparency') + ' = ' + Plugin.instance.get_i18n_string('tool.default.toggle_depth') + '.' +
          ' | ' + Plugin.instance.get_i18n_string("default.tab_key") + ' = ' + Plugin.instance.get_i18n_string('tool.smart_axes.action_1') + '.'
      when ACTION_SWAP_LENGTH_WIDTH
        return super +
          ' | ↑↓ + ' + Plugin.instance.get_i18n_string('tool.default.transparency') + ' = ' + Plugin.instance.get_i18n_string('tool.default.toggle_depth') + '.' +
          ' | ' + Plugin.instance.get_i18n_string("default.tab_key") + ' = ' + Plugin.instance.get_i18n_string('tool.smart_axes.action_2') + '.'
      when ACTION_SWAP_FRONT_BACK
        return super +
          ' | ↑↓ + ' + Plugin.instance.get_i18n_string('tool.default.transparency') + ' = ' + Plugin.instance.get_i18n_string('tool.default.toggle_depth') + '.' +
          ' | ' + Plugin.instance.get_i18n_string("default.tab_key") + ' = ' + Plugin.instance.get_i18n_string('tool.smart_axes.action_3') + '.'
      when ACTION_ADAPT_AXES
        return super +
          ' | ' + Plugin.instance.get_i18n_string("default.tab_key") + ' = ' + Plugin.instance.get_i18n_string('tool.smart_axes.action_0') + '.'
      end

      super
    end

    def get_action_cursor(action, modifier)

      case action
      when ACTION_SWAP_LENGTH_WIDTH
        return is_action_modifier_anticlockwise? ? @cursor_swap_length_width_anticlockwise : @cursor_swap_length_width_clockwise
      when ACTION_SWAP_FRONT_BACK
        return @cursor_swap_front_back
      when ACTION_FLIP
        return @cursor_flip
      when ACTION_ADAPT_AXES
        return @cursor_adapt_axes
      end

      super
    end

    def get_action_modifier_btn_child(action, modifier)

      case action
      when ACTION_SWAP_LENGTH_WIDTH
        case modifier
        when ACTION_MODIFIER_CLOCKWISE
          motif = Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,1L0,0.8333L0.1667,0.5L0.5,0.3333L0.8333,0.3333L0.6667,0L1,0.3333L0.6667,0.6667L0.8333,0.3333'))
          motif.line_width = @unit <= 4 ? 0.5 : 1
          return motif
        when ACTION_MODIFIER_ANTICLOCKWIZE
          motif = Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,1L0,0.8333L0.1667,0.5L0.5,0.3333L0.8333,0.3333L0.6667,0L1,0.3333L0.6667,0.6667L0.8333,0.3333'))
          motif.patterns_transformation = Geom::Transformation.translation(Geom::Vector3d.new(1, 0, 0)) * Geom::Transformation.scaling(-1, 1, 1)
          motif.line_width = @unit <= 4 ? 0.5 : 1
          return motif
        end
      when ACTION_FLIP
        case modifier
        when ACTION_MODIFIER_LENGTH
          lbl = Kuix::Label.new
          lbl.text = Plugin.instance.get_i18n_string('tool.smart_axes.action_modifier_length')
          return lbl
        when ACTION_MODIFIER_WIDTH
          lbl = Kuix::Label.new
          lbl.text = Plugin.instance.get_i18n_string('tool.smart_axes.action_modifier_width')
          return lbl
        when ACTION_MODIFIER_THICKNESS
          lbl = Kuix::Label.new
          lbl.text = Plugin.instance.get_i18n_string('tool.smart_axes.action_modifier_thickness')
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

    def is_action_flip?
      fetch_action == ACTION_FLIP
    end

    def is_action_swap_length_width?
      fetch_action == ACTION_SWAP_LENGTH_WIDTH
    end

    def is_action_swap_front_back?
      fetch_action == ACTION_SWAP_FRONT_BACK
    end

    def is_action_adapt_axes?
      fetch_action == ACTION_ADAPT_AXES
    end

    def is_action_modifier_length?
      fetch_action_modifier(fetch_action) == ACTION_MODIFIER_LENGTH
    end

    def is_action_modifier_width?
      fetch_action_modifier(fetch_action) == ACTION_MODIFIER_WIDTH
    end

    def is_action_modifier_thickness?
      fetch_action_modifier(fetch_action) == ACTION_MODIFIER_THICKNESS
    end

    def is_action_modifier_clockwise?
      fetch_action_modifier(fetch_action) == ACTION_MODIFIER_CLOCKWISE
    end

    def is_action_modifier_anticlockwise?
      fetch_action_modifier(fetch_action) == ACTION_MODIFIER_ANTICLOCKWIZE
    end

    # -- Menu --

    def populate_menu(menu)
      if @active_part
        active_part_id = @active_part.id
        active_part_material_type = @active_part.group.material_type
        item = menu.add_item("#{@active_part.saved_number ? "[#{@active_part.saved_number}] " : ''} #{@active_part.name}") {}
        menu.set_validation_proc(item) { MF_GRAYED }
        menu.add_separator
        menu.add_item(Plugin.instance.get_i18n_string('core.menu.item.edit_part_properties')) {
          Plugin.instance.execute_dialog_command_on_tab('cutlist', 'edit_part', "{ part_id: '#{active_part_id}', tab: 'general', dontGenerate: false }")
        }
        menu.add_item(Plugin.instance.get_i18n_string('core.menu.item.edit_part_axes_properties')) {
          Plugin.instance.execute_dialog_command_on_tab('cutlist', 'edit_part', "{ part_id: '#{active_part_id}', tab: 'axes', dontGenerate: false }")
        }
        item = menu.add_item(Plugin.instance.get_i18n_string('core.menu.item.edit_part_size_increase_properties')) {
          Plugin.instance.execute_dialog_command_on_tab('cutlist', 'edit_part', "{ part_id: '#{active_part_id}', tab: 'size_increase', dontGenerate: false }")
        }
        menu.set_validation_proc(item) {
          if active_part_material_type == MaterialAttributes::TYPE_SOLID_WOOD ||
            active_part_material_type == MaterialAttributes::TYPE_SHEET_GOOD ||
            active_part_material_type == MaterialAttributes::TYPE_DIMENSIONAL
            MF_ENABLED
          else
            MF_GRAYED
          end
        }
        item = menu.add_item(Plugin.instance.get_i18n_string('core.menu.item.edit_part_edges_properties')) {
          Plugin.instance.execute_dialog_command_on_tab('cutlist', 'edit_part', "{ part_id: '#{active_part_id}', tab: 'edges', dontGenerate: false }")
        }
        menu.set_validation_proc(item) {
          if active_part_material_type == MaterialAttributes::TYPE_SHEET_GOOD
            MF_ENABLED
          else
            MF_GRAYED
          end
        }
        item = menu.add_item(Plugin.instance.get_i18n_string('core.menu.item.edit_part_faces_properties')) {
          Plugin.instance.execute_dialog_command_on_tab('cutlist', 'edit_part', "{ part_id: '#{active_part_id}', tab: 'faces', dontGenerate: false }")
        }
        menu.set_validation_proc(item) {
          if active_part_material_type == MaterialAttributes::TYPE_SHEET_GOOD
            MF_ENABLED
          else
            MF_GRAYED
          end
        }
      else
        super
      end
    end

    # -- Events --

    def onActivate(view)
      super

      # Observe model events
      view.model.add_observer(self)

    end

    def onDeactivate(view)
      super

      # Stop observing model events
      view.model.remove_observer(self)

    end

    def onLButtonDown(flags, x, y, view)
      return true if super
      _handle_mouse_event(:l_button_down)
    end

    def onLButtonUp(flags, x, y, view)
      return true if super
      _handle_mouse_event(:l_button_up)
    end

    def onLButtonDoubleClick(flags, x, y, view)
      return true if super
      _handle_mouse_event(:l_button_dblclick)
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

    def onActionChange(action, modifier)
      _refresh_active_part
    end

    # -----

    protected

    def _set_active_part(part_entity_path, part, highlighted = false)
      super

      if part

        model = Sketchup.active_model

        # Show part infos

        infos = [ "#{part.length} x #{part.width} x #{part.thickness}" ]
        infos << "#{part.material_name} (#{Plugin.instance.get_i18n_string("tab.materials.type_#{part.group.material_type}")})" unless part.material_name.empty?
        infos << Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.5,0L0.5,0.2 M0.5,0.4L0.5,0.6 M0.5,0.8L0.5,1 M0,0.2L0.3,0.5L0,0.8L0,0.2 M1,0.2L0.7,0.5L1,0.8L1,0.2')) if part.flipped
        infos << Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.6,0L0.4,0 M0.6,0.4L0.8,0.2L0.5,0.2 M0.8,0.2L0.8,0.5 M0.8,0L1,0L1,0.2 M1,0.4L1,0.6 M1,0.8L1,1L0.8,1 M0.2,0L0,0L0,0.2 M0,1L0,0.4L0.6,0.4L0.6,1L0,1')) if part.resized

        notify_infos(part.name, infos)

        # Create drawing helpers

        instance_info = part.def.instance_infos.values.first

        arrow_color = part.auto_oriented ? COLOR_ARROW_AUTO_ORIENTED : COLOR_ARROW
        arrow_line_width = 2

        increases = [ 0, 0, 0 ]
        if part.length_increased || part.width_increased || part.thickness_increased
          part.def.size.axes.each_with_index do |axis, index|
            case index
            when 0
              increases[axis == X_AXIS ? 0 : (axis == Y_AXIS ? 1 : 2)] = part.def.length_increase.to_f if part.length_increased
            when 1
              increases[axis == X_AXIS ? 0 : (axis == Y_AXIS ? 1 : 2)] = part.def.width_increase.to_f if part.width_increased
            when 2
              increases[axis == X_AXIS ? 0 : (axis == Y_AXIS ? 1 : 2)] = part.def.thickness_increase.to_f if part.thickness_increased
            end
          end
        end

        part_helper = Kuix::Group.new
        part_helper.transformation = instance_info.transformation
        @space.append(part_helper)

        show_axes = true
        if is_action_adapt_axes? && part.group.material_type != MaterialAttributes::TYPE_HARDWARE

          origin, x_axis, y_axis, z_axis, input_face, input_edge = _get_input_axes(instance_info)

          # Highlight input edge
          segments = Kuix::Segments.new
          segments.add_segments(_compute_children_edge_segments(instance_info.entity.definition.entities, nil,[ input_edge ]))
          segments.color = COLOR_ACTION
          segments.line_width = 5
          part_helper.append(segments)

          # Highlight input face
          mesh = Kuix::Mesh.new
          mesh.add_triangles(_compute_children_faces_triangles(instance_info.entity.definition.entities, nil,[ input_face ]))
          mesh.background_color = COLOR_ACTION_FILL
          part_helper.append(mesh)

          t = Geom::Transformation.axes(origin, x_axis, y_axis, z_axis)
          unless (t * part.def.size.oriented_transformation).identity?

            show_axes = false

            bounds = Geom::BoundingBox.new
            bounds.add(_compute_children_faces_triangles(instance_info.entity.definition.entities, t.inverse))

            # Front arrow
            arrow = Kuix::ArrowMotif.new
            arrow.patterns_transformation = Geom::Transformation.translation(Z_AXIS)
            arrow.bounds.origin.copy!(bounds.min)
            arrow.bounds.size.copy!(bounds)
            arrow.color = COLOR_ACTION
            arrow.line_width = arrow_line_width
            arrow.transformation = t
            part_helper.append(arrow)

            # Box helper
            box_helper = Kuix::BoxMotif.new
            box_helper.bounds.origin.copy!(bounds.min)
            box_helper.bounds.size.copy!(bounds)
            box_helper.bounds.size.width += increases[0] / part.def.scale.x
            box_helper.bounds.size.height += increases[1] / part.def.scale.y
            box_helper.bounds.size.depth += increases[2] / part.def.scale.z
            box_helper.color = COLOR_ACTION
            box_helper.line_width = 2
            box_helper.line_stipple = '-'
            box_helper.transformation = t
            part_helper.append(box_helper)

            # Axes helper
            axes_helper = Kuix::AxesHelper.new
            axes_helper.transformation = t
            part_helper.append(axes_helper)

          end

        end

        if is_action_flip?

          transformation_inverse = instance_info.transformation.inverse

          rect_offset = model.active_view.pixels_to_model(20, model.active_view.guess_target)
          rect_offset_bounds = Geom::BoundingBox.new
          rect_offset_bounds.add(Geom::Point3d.new.transform!(transformation_inverse))
          rect_offset_bounds.add(Geom::Point3d.new(rect_offset, rect_offset, rect_offset).transform!(transformation_inverse))

          r_width = 0
          r_height = 0
          r_t = Geom::Transformation.translation(instance_info.definition_bounds.center)
          r_t *= instance_info.size.oriented_transformation

          if is_action_modifier_length?
            r_width += _get_bounds_dim_along_axis(instance_info, instance_info.definition_bounds, Y_AXIS) + _get_bounds_dim_along_axis(instance_info, rect_offset_bounds, Y_AXIS) * 2
            r_height += _get_bounds_dim_along_axis(instance_info, instance_info.definition_bounds, Z_AXIS) + _get_bounds_dim_along_axis(instance_info, rect_offset_bounds, Z_AXIS) * 2
            r_t *= Geom::Transformation.rotation(ORIGIN, Z_AXIS, 90.degrees) * Geom::Transformation.rotation(ORIGIN, X_AXIS, 90.degrees)
          elsif is_action_modifier_width?
            r_width += _get_bounds_dim_along_axis(instance_info, instance_info.definition_bounds, X_AXIS) + _get_bounds_dim_along_axis(instance_info, rect_offset_bounds, X_AXIS) * 2
            r_height += _get_bounds_dim_along_axis(instance_info, instance_info.definition_bounds, Z_AXIS) + _get_bounds_dim_along_axis(instance_info, rect_offset_bounds, Z_AXIS) * 2
            r_t *= Geom::Transformation.rotation(ORIGIN, X_AXIS, 90.degrees)
          elsif is_action_modifier_thickness?
            r_width += _get_bounds_dim_along_axis(instance_info, instance_info.definition_bounds, X_AXIS) + _get_bounds_dim_along_axis(instance_info, rect_offset_bounds, X_AXIS) * 2
            r_height += _get_bounds_dim_along_axis(instance_info, instance_info.definition_bounds, Y_AXIS) + _get_bounds_dim_along_axis(instance_info, rect_offset_bounds, Y_AXIS) * 2
          end
          r_t *= Geom::Transformation.translation(Geom::Vector3d.new(r_width / -2.0, r_height / -2.0, 0))
          r_t *= Geom::Transformation.scaling(ORIGIN, r_width, r_height, 0)

          rect = Kuix::RectangleMotif.new
          rect.bounds.size.set!(1, 1, 0)
          rect.transformation = r_t
          rect.color = COLOR_ACTION
          rect.line_width = 2
          part_helper.append(rect)

            fill = Kuix::Mesh.new
            fill.add_triangles([
                                 Geom::Point3d.new(0, 0, 0), Geom::Point3d.new(1, 0, 0), Geom::Point3d.new(1, 1, 0),
                                 Geom::Point3d.new(0, 0, 0), Geom::Point3d.new(0, 1, 0), Geom::Point3d.new(1, 1, 0)
                               ])
            fill.background_color = COLOR_ACTION_FILL
            rect.append(fill)

        end

        if part.group.material_type != MaterialAttributes::TYPE_HARDWARE

          # Back arrow
          arrow = Kuix::ArrowMotif.new
          arrow.patterns_transformation = instance_info.size.oriented_transformation
          arrow.bounds.origin.copy!(instance_info.definition_bounds.min)
          arrow.bounds.size.copy!(instance_info.definition_bounds)
          arrow.color = arrow_color
          arrow.line_width = arrow_line_width
          arrow.line_stipple = '-'
          part_helper.append(arrow)

          # Front arrow
          arrow = Kuix::ArrowMotif.new
          arrow.patterns_transformation = instance_info.size.oriented_transformation
          arrow.patterns_transformation *= Geom::Transformation.translation(Z_AXIS)
          arrow.bounds.origin.copy!(instance_info.definition_bounds.min)
          arrow.bounds.size.copy!(instance_info.definition_bounds)
          arrow.color = arrow_color
          arrow.line_width = arrow_line_width
          part_helper.append(arrow)

          # Bounding box helper
          box_helper = Kuix::BoxMotif.new
          box_helper.bounds.origin.copy!(instance_info.definition_bounds.min)
          box_helper.bounds.size.copy!(instance_info.definition_bounds)
          box_helper.bounds.size.width += increases[0] / part.def.scale.x
          box_helper.bounds.size.height += increases[1] / part.def.scale.y
          box_helper.bounds.size.depth += increases[2] / part.def.scale.z
          box_helper.color = COLOR_BOX
          box_helper.line_width = 2
          box_helper.line_stipple = '-'
          part_helper.append(box_helper)

        end

        if show_axes

          # Axes helper
          axes_helper = Kuix::AxesHelper.new
          axes_helper.transformation = Geom::Transformation.scaling(1 / part.def.scale.x, 1 / part.def.scale.y, 1 / part.def.scale.z)
          part_helper.append(axes_helper)

        end

        # Mesh
        instance_paths = []
        if is_action_flip?

          # Only current instance
          instance_paths << part_entity_path

        else

          # All instances
          unless part_entity_path.nil?
            active_instance = part_entity_path.last
            instances = active_instance.definition.instances
            _instances_to_paths(instances, instance_paths, model.active_entities, model.active_path ? model.active_path : [])
          end

        end
        instance_paths.each do |path|

          mesh = Kuix::Mesh.new
          mesh.add_triangles(_compute_children_faces_triangles(path.last.definition.entities))
          mesh.background_color = highlighted ? COLOR_MESH_HIGHLIGHTED : COLOR_MESH
          mesh.transformation = PathUtils::get_transformation(path)
          @space.append(mesh)

        end

        # Status

        if !is_action_flip? && part.group.material_type == MaterialAttributes::TYPE_HARDWARE
          notify_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_axes.error.not_orientable')}", MESSAGE_TYPE_ERROR)
          push_cursor(@cursor_select_error)
          return
        end

        if !is_action_flip?
          definition = model.definitions[part.def.definition_id]
          if definition && definition.count_used_instances > 1
            notify_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_axes.warning.more_entities', { :count_used => definition.count_used_instances })}", MESSAGE_TYPE_WARNING)
          end
        end

      end

    end

    def _can_pick_deeper?
      super && !is_action_adapt_axes?
    end

    # -----

    private

    def _handle_mouse_event(event = nil)
      if event == :move

        if @input_face_path
          input_part_entity_path = _get_part_entity_path_from_path(@input_face_path)
          if input_part_entity_path

            part = _generate_part_from_path(input_part_entity_path)
            if part
              _set_active_part(input_part_entity_path, part)
            else
              _reset_active_part
              notify_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_axes.error.not_part')}", MESSAGE_TYPE_ERROR)
              push_cursor(@cursor_select_error)
            end
            return

          else
            _reset_active_part
            notify_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_axes.error.not_part')}", MESSAGE_TYPE_ERROR)
            push_cursor(@cursor_select_error)
            return
          end
        end
        _reset_active_part  # No input

      elsif event == :l_button_down

        _refresh_active_part(true)

      elsif event == :l_button_up || event == :l_button_dblclick

        if @active_part && (is_action_flip? || @active_part.group.material_type != MaterialAttributes::TYPE_HARDWARE)

          model = Sketchup.active_model
          definition = model.definitions[@active_part.def.definition_id]
          unless definition.nil?

            size = @active_part.def.size

            ti = nil
            if is_action_flip?

              entity = @active_part_entity_path.last
              bounds = _compute_faces_bounds(entity.definition)

              scaling = {
                X_AXIS => 1,
                Y_AXIS => 1,
                Z_AXIS => 1,
              }
              if is_action_modifier_length?
                scaling[size.oriented_axis(X_AXIS)] = -1
              elsif is_action_modifier_width?
                scaling[size.oriented_axis(Y_AXIS)] = -1
              elsif is_action_modifier_thickness?
                scaling[size.oriented_axis(Z_AXIS)] = -1
              end

              t = Geom::Transformation.scaling(bounds.center, scaling[X_AXIS], scaling[Y_AXIS], scaling[Z_AXIS])

              # Start undoable model modification operation
              model.start_operation('OCL Part Flip', true, false, false)

              entity.transformation *= t

              # Commit model modification operation
              model.commit_operation

              # Refresh active
              _refresh_active_part

            elsif is_action_swap_length_width?

              if is_action_modifier_anticlockwise?
                ti = Geom::Transformation.axes(
                  ORIGIN,
                  size.axes[1],
                  AxisUtils.flipped?(size.axes[1], size.axes[0], size.axes[2]) ? size.axes[0].reverse : size.axes[0],
                  size.axes[2]
                )
              else
                ti = Geom::Transformation.axes(
                  ORIGIN,
                  AxisUtils.flipped?(size.axes[1], size.axes[0], size.axes[2]) ? size.axes[1].reverse : size.axes[1],
                  size.axes[0],
                  size.axes[2]
                )
              end

            elsif is_action_swap_front_back?

              ti = Geom::Transformation.axes(
                ORIGIN,
                size.axes[0],
                AxisUtils.flipped?(size.axes[0], size.axes[1], size.axes[2].reverse) ? size.axes[1].reverse : size.axes[1],
                size.axes[2].reverse
              )

            elsif is_action_adapt_axes?

              instance_info = @active_part.def.instance_infos.values.first
              origin, x_axis, y_axis, z_axis = _get_input_axes(instance_info)
              ti = Geom::Transformation.axes(origin, x_axis, y_axis, z_axis)

            end
            unless ti.nil?

              t = ti.inverse

              # Start undoable model modification operation
              model.start_operation('OCL Change Axes', true, false, false)

              # Transform definition's entities
              entities = definition.entities
              entities.transform_entities(t, entities.to_a)

              # Inverse transform definition's instances
              definition.instances.each { |instance|
                instance.transformation *= ti
              }

              if Plugin.instance.get_model_preset('cutlist_options').fetch('auto_orient')
                definition_attributes = DefinitionAttributes.new(definition)
                definition_attributes.orientation_locked_on_axis = true
                definition_attributes.write_to_attributes
              end

              # Commit model modification operation
              model.commit_operation

              # Refresh active
              _refresh_active_part

            end

          end

        else
          UI.beep
        end

      end
    end

    def _get_input_axes(instance_info)

      input_face = @input_face
      if input_face.nil?
        input_face, inner_path = _find_largest_face(instance_info.entity, instance_info.transformation)
      else
        inner_path = @input_face_path - instance_info.path
      end

      inner_transformation = PathUtils.get_transformation(inner_path)

      input_edge = @input_edge
      if input_edge.nil? || !input_edge.used_by?(input_face)
        input_edge = _find_longest_outer_edge(input_face, TransformationUtils.multiply(instance_info.transformation, inner_transformation))
      end

      z_axis = input_face.normal
      z_axis.transform!(inner_transformation).normalize! unless inner_transformation.nil?

      x_axis = input_edge.line[1]
      x_axis.transform!(inner_transformation).normalize! unless inner_transformation.nil?
      x_axis.reverse! if x_axis.angle_between(instance_info.size.oriented_axis(X_AXIS)) >= Math::PI / 2 # Try to keep part length orientation

      y_axis = z_axis.cross(x_axis)

      [ ORIGIN, x_axis, y_axis, z_axis, input_face, input_edge ]
    end

    def _get_bounds_dim_along_axis(instance_info, bounds, axis)
      begin
        case instance_info.size.oriented_axis(axis)
        when X_AXIS
          return bounds.width
        when Y_AXIS
          return bounds.height
        when Z_AXIS
          return bounds.depth
        else
          return 0
        end
      rescue
        return 0
      end
    end

  end

end
