module Alchemy
  module Admin

    # This module contains helper methods for rendering overlay windows, toolbar buttons and confirmation windows.
    #
    # The most important helpers for module developers are:
    #
    # * {#toolbar}
    # * {#toolbar_button}
    # * {#link_to_overlay_window}
    # * {#link_to_confirmation_window}
    #
    module BaseHelper
      include Alchemy::BaseHelper
      include Alchemy::Admin::NavigationHelper

      # This helper renders the link to an overlay window.
      #
      # We use this for our fancy modal overlay windows in the Alchemy cockpit.
      #
      # == Example
      #
      #   <%= link_to_overlay_window('Edit', edit_product_path, {size: '200x300'}, {class: 'icon_button'}) %>
      #
      # @param [String] content
      #   The string inside the link tag
      # @param [String or Hash] url
      #   The url of the action displayed inside the overlay window.
      # @param [Hash] options
      #   options for the overlay window.
      # @param [Hash] html_options
      #   HTML options passed to the <tt>link_to</tt> helper
      #
      # @option options [String] :size
      #    String with format of "WidthxHeight". I.E. ("420x280")
      # @option options [String] :title
      #    Text for the overlay title bar.
      # @option options [Boolean] :overflow (false)
      #    Should the dialog have overlapping content. If not, it shows scrollbars. Good for select boxes.
      # @option options [Boolean] :resizable (false)
      #    Is the dialog window resizable?
      # @option options [Boolean] :modal (true)
      #    Show as modal window.
      # @option options [Boolean] :overflow (true)
      #    Should the window show overflowing content?
      #
      def link_to_overlay_window(content, url, options={}, html_options={})
        ActiveSupport::Deprecation.warn("Used deprecated link_to_overlay_window helper. It will be removed in Alchemy v3.0. Please use link_to_dialog instead.")
        default_options = {
          :modal => true,
          :overflow => true,
          :resizable => false
        }
        options = default_options.merge(options)
        size = options.delete(:size).to_s.split('x')
        link_to(content, url,
          html_options.merge(
            'data-alchemy-overlay' => options.update(
              :width => size && size[0] ? size[0] : 'auto',
              :height => size && size[1] ? size[1] : 'auto',
            ).to_json
          )
        )
      end

      # Used for language selector in Alchemy cockpit sitemap. So the user can select the language branche of the page.
      def language_codes_for_select
        configuration(:languages).collect { |language|
          language[:language_code]
        }
      end

      # Used for translations selector in Alchemy cockpit user settings.
      def translations_for_select
        Alchemy::I18n.available_locales.map do |locale|
          [_t(locale, :scope => :translations), locale]
        end
      end

      # Returns a javascript driven live filter for lists.
      #
      # The items must have a html +name+ attribute that holds the filterable value.
      #
      # == Example
      #
      # Given a list of items:
      #
      #   <%= js_filter_field('#products .product') %>
      #
      #   <ul id="products">
      #     <li class="product" name="kat litter">Kat Litter</li>
      #     <li class="product" name="milk">Milk</li>
      #   </ul>
      #
      # @param [String] items
      #   A jquery compatible selector string that represents the items to filter
      # @param [Hash] options
      #   HTML options passed to the input field
      #
      # @option options [String] :class ('js_filter_field')
      #   The css class of the <input> tag
      # @option options [String or Hash] :data ({'alchemy-list-filter' => items})
      #   A HTML data attribute that holds the jQuery selector that represents the list to be filtered
      #
      def js_filter_field(items, options = {})
        options = {
          class: 'js_filter_field',
          data: {'alchemy-list-filter' => items}
        }.merge(options)
        content_tag(:div, class: 'js_filter_field_box') do
          concat text_field_tag(nil, nil, options)
          concat content_tag('span', '', class: 'icon search')
          concat link_to('', '', class: 'js_filter_field_clear', title: _t(:click_to_show_all))
          concat content_tag(:label, _t(:search), for: options[:id])
        end
      end

      # Returns a link that opens a modal confirmation to delete window.
      #
      # === Example:
      #
      #   <%= link_to_confirmation_window('delete', 'Do you really want to delete this comment?', '/admin/comments/1') %>
      #
      # @param [String] link_string
      #   The content inside the <a> tag
      # @param [String] message
      #   The message that is displayed in the overlay window
      # @param [String] url
      #   The url that gets opened after confirmation (Note: This is an Ajax request with a method of DELETE!)
      # @param [Hash] html_options
      #   HTML options get passed to the link
      #
      # @option html_options [String] :title (_t(:please_confirm))
      #   The overlay title
      # @option html_options [String] :message (message)
      #   The message displayed in the overlay
      # @option html_options [String] :ok_label (_t("Yes"))
      #   The label for the ok button
      # @option html_options [String] :cancel_label (_t("No"))
      #   The label for the cancel button
      #
      def link_to_confirmation_window(link_string = "", message = "", url = "", html_options = {})
        ActiveSupport::Deprecation.warn("Used deprecated link_to_confirmation_window helper. It will be removed in Alchemy v3.0. Please use link_to_confirm_dialog instead.")
        link_to(link_string, url,
          html_options.merge(
            'data-alchemy-confirm-delete' => {
              :title => _t(:please_confirm),
              :message => message,
              :ok_label => _t("Yes"),
              :cancel_label => _t("No")
            }.to_json
          )
        )
      end

      # Returns a form and a button that opens a modal confirm window.
      #
      # After confirmation it proceeds to send the form's action.
      #
      # === Example:
      #
      #   <%= button_with_confirm('pay', '/admin/orders/1/pay', message: 'Do you really want to mark this order as payed?') %>
      #
      # @param [String] value
      #   The content inside the <tt><a></tt> tag
      # @param [String] url
      #   The url that gets opened after confirmation
      # @param [Hash] options
      #   Options for the Alchemy confirm overlay (see also +app/assets/javascripts/alchemy/alchemy.window.js#openConfirmWindow+)
      # @param [Hash] html_options
      #   HTML options that get passed to the +button_tag+ helper.
      #
      # @note The method option in the <tt>html_options</tt> hash gets passed to the <tt>form_tag</tt> helper!
      #
      def button_with_confirm(value = "", url = "", options = {}, html_options = {})
        options = {
          message: _t(:confirm_to_proceed),
          ok_label: _t("Yes"),
          title: _t(:please_confirm),
          cancel_label: _t("No")
        }.merge(options)
        form_tag url, {method: html_options.delete(:method)} do
          button_tag value, html_options.merge('data-alchemy-confirm' => options.to_json)
        end
      end

      # (internal) Renders translated Module Names for html title element.
      def render_alchemy_title
        if content_for?(:title)
          title = content_for(:title)
        else
          title = _t(controller_name, :scope => :modules)
        end
        "Alchemy CMS - #{title}"
      end

      # (internal) Returns max image count as integer or nil. Used for the picture editor in element editor views.
      def max_image_count
        return nil if !@options
        image_count = @options[:maximum_amount_of_images] || @options[:max_images]
        image_count.blank? ? nil : image_count.to_i
      end

      # (internal) Renders a select tag for all items in the clipboard
      def clipboard_select_tag(items, html_options = {})
        options = [[_t('Please choose'), ""]]
        items.each do |item|
          options << [item.class.to_s == 'Alchemy::Element' ? item.display_name_with_preview_text : item.name, item.id]
        end
        select_tag(
          'paste_from_clipboard',
          !@page.new_record? && @page.can_have_cells? ? grouped_elements_for_select(items, :id) : options_for_select(options),
          {
            :class => [html_options[:class], 'alchemy_selectbox'].join(' '),
            :style => html_options[:style]
          }
        )
      end

      # Renders a toolbar button for the Alchemy toolbar
      #
      # == Example
      #
      #   <%= toolbar_button(
      #     icon: 'create',
      #     label: 'Create',
      #     url: new_resource_path,
      #     title: 'Create Resource',
      #     hotkey: 'alt-n',
      #     overlay_options: {
      #       title: 'Create Resource',
      #       size: "430x400"
      #     },
      #     if_permitted_to: [:new, resource_permission_scope]
      #   ) %>
      #
      # @option options [String] :icon
      #   Icon class. See +app/assets/stylesheets/alchemy/icons.css.sccs+ for available icons, or make your own.
      # @option options [String] :label
      #   Text for button label.
      # @option options [String] :url
      #   Url for link.
      # @option options [String] :title
      #   Text for title tag.
      # @option options [String] :hotkey
      #   Keyboard shortcut for this button. I.E +alt-n+
      # @option options [Boolean] :overlay (true)
      #   Open the link in a modal overlay window.
      # @option options [Hash] :overlay_options
      #   Overlay options. See link_to_overlay_window helper.
      # @option options [Array] :if_permitted_to ([:action, :controller])
      #   Check permission for button. Exactly how you defined the permission in your +authorization_rules.rb+. Defaults to controller and action from button url.
      # @option options [Boolean] :skip_permission_check (false)
      #   Skip the permission check. NOT RECOMMENDED!
      # @option options [Boolean] :loading_indicator (true)
      #   Shows the please wait overlay while loading. Only for buttons not opening an overlay window.
      #
      def toolbar_button(options = {})
        options = {
          overlay: true,
          skip_permission_check: false,
          active: false,
          link_options: {},
          overlay_options: {},
          loading_indicator: true
        }.merge(options.symbolize_keys)
        button = render(
          'alchemy/admin/partials/toolbar_button',
          options: options
        )
        if options[:skip_permission_check] || permitted_to?(*permission_from_options(options))
          button
        else
          ""
        end
      end

      # Renders the toolbar shown on top of the records.
      #
      # == Example
      #
      #   <% label_title = _t("Create #{resource_name}", default: _t('Create')) %>
      #   <% toolbar(
      #     buttons: [
      #       {
      #         icon: 'create',
      #         label: label_title,
      #         url: new_resource_path,
      #         title: label_title,
      #         hotkey: 'alt-n',
      #         overlay_options: {
      #           title: label_title,
      #           size: "430x400"
      #         },
      #         if_permitted_to: [:new, resource_permission_scope]
      #       }
      #     ]
      #   ) %>
      #
      # @option options [Array] :buttons ([])
      #   Pass an Array with button options. They will be passed to {#toolbar_button} helper.
      # @option options [Boolean] :search (true)
      #   Show searchfield.
      #
      def toolbar(options = {})
        defaults = {
          :buttons => [],
          :search => true
        }
        options = defaults.merge(options)
        content_for(:toolbar) do
          content = <<-CONTENT
#{options[:buttons].map { |button_options| toolbar_button(button_options) }.join()}
          #{render('alchemy/admin/partials/search_form', :url => options[:search_url]) if options[:search]}
          CONTENT
          content.html_safe
        end
      end

      # Renders the row for a resource record in the resources table.
      #
      # This helper has a nice fallback. If you create a partial for your record then this partial will be rendered.
      #
      # Otherwise the default +app/views/alchemy/admin/resources/_resource.html.erb+ partial gets rendered.
      #
      # == Example
      #
      # For a resource named +Comment+ you can create a partial named +_comment.html.erb+
      #
      #   # app/views/admin/comments/_comment.html.erb
      #   <tr>
      #     <td><%= comment.title %></td>
      #     <td><%= comment.body %></td>
      #   </tr>
      #
      # NOTE: Alchemy gives you a local variable named like your resource
      #
      def render_resources
        render :partial => resource_name, :collection => resources_instance_variable
      rescue ActionView::MissingTemplate
        render :partial => 'resource', :collection => resources_instance_variable
      end

      # (internal) Used by upload form
      def new_asset_path_with_session_information(asset_type)
        session_key = Rails.application.config.session_options[:key]
        if asset_type == "picture"
          alchemy.admin_pictures_path(session_key => cookies[session_key], request_forgery_protection_token => form_authenticity_token, :format => :js)
        elsif asset_type == "attachment"
          alchemy.admin_attachments_path(session_key => cookies[session_key], request_forgery_protection_token => form_authenticity_token, :format => :js)
        end
      end

      # Renders a textfield ready to display a datepicker
      #
      # Uses a HTML5 <tt><input type="date"></tt> field.
      #
      # === Example
      #
      #   <%= alchemy_datepicker(@person, :birthday) %>
      #
      # @param [ActiveModel::Base] object
      #   An instance of a model
      # @param [String or Symbol] method
      #   The attribute method to be called for the date value
      #
      # @option html_options [String] :type ('date')
      #   The type of text field
      # @option html_options [String] :class ('thin_border date')
      #   CSS classes of the input field
      # @option html_options [String] :value (object.send(method.to_sym).nil? ? nil : l(object.send(method.to_sym), :format => :datepicker))
      #   The value the input displays
      #
      def alchemy_datepicker(object, method, html_options={})
        text_field(object.class.name.underscore.to_sym, method.to_sym, {
          :type => 'date',
          :class => 'thin_border date',
          :value => object.send(method.to_sym).nil? ? nil : l(object.send(method.to_sym), :format => :datepicker)
        }.merge(html_options))
      end

      # Merges the params-hash with the given hash
      def merge_params(p={})
        params.merge(p).delete_if { |k, v| v.blank? }
      end

      # Deletes one or several params from the params-hash and merges some new params in
      def merge_params_without(excludes, p={})
        current_params = params.clone.symbolize_keys
        if excludes.is_a?(Array)
          excludes.map { |i| current_params.delete(i.to_sym) }
        else
          current_params.delete(excludes.to_sym)
        end
        current_params.merge(p).delete_if { |k, v| v.blank? }
      end

      # Deletes all params from the params-hash except the given ones and merges some new params in
      def merge_params_only(includes, p={})
        current_params = params.clone.symbolize_keys
        if includes.is_a?(Array)
          symbolized_includes = includes.map(&:to_sym)
          current_params.delete_if { |k, v| !symbolized_includes.include?(k) }
        else
          current_params.delete_if { |k, v| k != includes.to_sym }
        end
        current_params.merge(p).delete_if { |k, v| v.blank? }
      end

      def render_hint_for(element)
        return unless element.has_hint?
        link_to '#', :class => 'hint' do
          render_icon(:hint) + content_tag(:span, element.hint.html_safe, :class => 'bubble')
        end
      end

      # Appends the current controller and action to body as css class.
      def body_class
        "#{controller_name} #{action_name}"
      end

    private

      def permission_from_options(options)
        if options[:if_permitted_to].blank?
          options[:if_permitted_to] = permission_array_from_url(options)
        else
          options[:if_permitted_to]
        end
      end

      def permission_array_from_url(options)
        action_controller = options[:url].gsub(/^\//, '').split('/')
        [
          action_controller.last.to_sym,
          action_controller[0..action_controller.length-2].join('_').to_sym
        ]
      end

    end
  end
end
