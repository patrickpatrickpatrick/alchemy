module Alchemy
  module Admin
    class AttachmentsController < ResourcesController
      helper 'alchemy/admin/tags'

      protect_from_forgery :except => [:create]

      def index
        @attachments = Attachment.scoped
        @attachments = @attachments.tagged_with(params[:tagged_with]) if params[:tagged_with].present?
        @attachments = @attachments.find_paginated(params, 15, sort_order)
        if in_overlay?
          archive_overlay
        else
          # render index.html.erb
        end
      end

      def new
        @attachment = Attachment.new
        if in_overlay?
          @while_assigning = true
          @content = Content.find(params[:content_id], :select => 'id')
          @swap = params[:swap]
          @options = options_from_params
        end
        render :layout => !request.xhr?
      end

      def create
        @attachment = Attachment.create!(:file => params[:Filedata])
        if in_overlay?
          @while_assigning = true
          @content = Content.find(params[:content_id], :select => 'id') if !params[:content_id].blank?
          @swap = params[:swap]
          @options = options_from_params
        end
        @attachments = Attachment.find_paginated(params, per_page_value_for_screen_size, sort_order)
        @message = _t('File %{name} uploaded succesfully', :name => @attachment.name)
        # Are we using the Flash uploader? Or the plain html file uploader?
        if params[Rails.application.config.session_options[:key]].blank?
          flash[:notice] = @message
          redirect_to :action => :index
        end
      end

      def edit
        @attachment = Attachment.find(params[:id])
        render layout: !request.xhr?
      end

      def update
        @attachment = Attachment.find(params[:id])
        oldname = @attachment.name
        @attachment.update_attributes(params[:attachment])
        render_errors_or_redirect(
          @attachment,
          admin_attachments_path(:page => params[:page], :query => params[:query], :per_page => params[:per_page]),
          _t("File successfully updated")
        )
      end

      def destroy
        @attachment = Attachment.find(params[:id])
        name = @attachment.name
        @attachment.destroy
        @url = admin_attachments_url(
          per_page: params[:per_page],
          page: params[:page],
          query: params[:query]
        )
        flash[:notice] = _t("File: '%{name}' deleted successfully", name: name)
      end

      def show
        @attachment = Attachment.find(params[:id])
        render layout: !request.xhr?
      end

      def download
        @attachment = Attachment.find(params[:id])
        send_data(
          @attachment.file.data, {
            :filename => @attachment.file_name,
            :type => @attachment.file_mime_type
          }
        )
      end

    private

      def in_overlay?
        params[:content_id].present?
      end

      def archive_overlay
        @content = Content.find(params[:content_id], select: 'id')
        @options = options_from_params
        respond_to do |format|
          format.html {
            render partial: 'archive_overlay'
          }
          format.js {
            render action: 'archive_overlay'
          }
        end
      end

    end
  end
end
