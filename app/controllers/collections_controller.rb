class CollectionsController < ManageCollectionsController
  include ManageMetadataHelper
  include CMRCollectionsHelper

  before_action :set_collection
  before_action :ensure_correct_collection_provider, only: [:edit, :clone, :revert, :destroy]

  layout 'collection_preview', only: [:show]

  add_breadcrumb 'Collections' # there is no collections index action, so not providing a link

  def show
    @language_codes = cmr_client.get_language_codes

    add_breadcrumb fetch_entry_id(@collection, 'collections'), collection_path(@concept_id)

    if Rails.configuration.proposal_mode
      render 'proposal/collections/show'
    else
      @draft = CollectionDraft.where(provider_id: @provider_id, native_id: @native_id).first
      render :show
    end
  end

  def edit
    draft = CollectionDraft.create_from_collection(@collection, current_user, @native_id)
    Rails.logger.info("Audit Log: Collection Draft for #{draft.entry_title} was created by #{current_user.urs_uid} in provider #{current_user.provider_id}")
    redirect_to collection_draft_path(draft), flash: { success: I18n.t('controllers.draft.collection_drafts.create.flash.success') }
  end

  def clone
    draft = CollectionDraft.create_from_collection(@collection, current_user, nil)
    Rails.logger.info("Audit Log: Cloned Collection Draft for #{draft.entry_title} was created by #{current_user.urs_uid} in provider #{current_user.provider_id}")
    flash[:notice] = view_context.link_to I18n.t('controllers.collections.clone.flash.notice'), edit_collection_draft_path(draft, 'collection_information', anchor: 'collection-information')
    redirect_to collection_draft_path(draft)
  end

  def destroy
    provider_id = @revisions.first['meta']['provider-id']
    delete_response = cmr_client.delete_collection(provider_id, @native_id, token)
    if delete_response.success?
      flash[:success] = I18n.t('controllers.collections.destroy.flash.success')
      Rails.logger.info("Audit Log: Collection with native_id #{@native_id} was deleted for #{provider_id} by #{session[:urs_uid]}")
      redirect_to collection_revisions_path(id: delete_response.body['concept-id'], revision_id: delete_response.body['revision-id'])
    else
      Rails.logger.error("Delete Collection Error: #{delete_response.clean_inspect}")
      Rails.logger.info("User #{current_user.urs_uid} attempted to delete Collection #{@concept_id} with native_id #{@native_id} in provider #{provider_id} but encountered an error.")

      flash[:error] = delete_response.error_message(i18n: I18n.t('controllers.collections.destroy.flash.error'))
      render :show
    end
  end

  def revisions
    add_breadcrumb fetch_entry_id(@collection, 'collections'), collection_path(@concept_id)
    add_breadcrumb 'Revision History', collection_revisions_path(@concept_id)
  end

  def revert
    latest_revision_id = @revisions.first['meta']['revision-id']

    # Ingest revision
    metadata = @collection_format.include?('umm+json') ? @collection.to_json : @collection
    ingested_response = cmr_client.ingest_collection(metadata, @provider_id, @native_id, token, @collection_format)

    if ingested_response.success?
      flash[:success] = I18n.t('controllers.collections.revert.flash.success')
      Rails.logger.info("Audit Log: Collection Revision for record #{@concept_id} with native_id: #{@native_id} for provider: #{@provider_id} by user #{session[:urs_uid]} has been successfully revised")
      redirect_to collection_revisions_path(revision_id: latest_revision_id.to_i + 1)
    else
      Rails.logger.error("Ingest (Revert) Collection Error: #{ingested_response.clean_inspect}")
      Rails.logger.info("User #{current_user.urs_uid} attempted to revert Collection #{@concept_id} by ingesting a previous revision in provider #{current_user.provider_id} but encountered an error.")

      @errors = generate_ingest_errors(ingested_response)
      flash[:error] = ingested_response.error_message(i18n: I18n.t('controllers.collections.revert.flash.error'))
      render action: 'revisions'
    end
  end

  def download_xml
    concept_id = params[:id]
    download_format = params[:format]
    revision_id = params[:revision_id]

    collection_response = cmr_client.get_concept(concept_id, token, {}, revision_id, download_format)

    if collection_response.error?
      Rails.logger.error("Error retrieving concept for download for Collection #{concept_id}, revision #{revision_id} in #{download_format} format for user #{current_user.urs_uid}")
    end

    collection_download = collection_response.body
    content_type = collection_response.headers.fetch('content-type', '')

    send_data collection_download, type: content_type, disposition: "attachment; filename=#{concept_id}.#{download_format}"
  end

  def create_delete_proposal
    proposal = CollectionDraftProposal.create_request(collection: @collection, user: current_user, provider_id: @provider_id, native_id: @native_id, request_type: 'delete', username: session[:name])
    Rails.logger.info("Audit Log: Delete Collection Proposal Request for #{proposal.entry_title} with concept #{@concept_id} was created by #{current_user.urs_uid}")
    flash[:success] = I18n.t('controllers.collections.delete_proposal.flash.success')
    redirect_to collection_draft_proposal_path(proposal)
  end

  def create_update_proposal
    proposal = CollectionDraftProposal.create_request(collection: @collection, user: current_user, provider_id: @provider_id, native_id: @native_id, request_type: 'update', username: session[:name])
    Rails.logger.info("Audit Log: Update Collection Proposal Request for #{proposal.entry_title} with concept #{@concept_id} was created by #{current_user.urs_uid}")
    flash[:success] = I18n.t('controllers.collections.update_proposal.flash.success')
    redirect_to collection_draft_proposal_path(proposal)
  end

  private

  def ensure_correct_collection_provider
    return if current_provider?(@provider_id)

    set_record_action

    set_user_permissions

    render :show
  end

  def set_collection
    @concept_id = params[:id]
    @revision_id = params[:revision_id]

    @revisions = get_revisions(@concept_id, @revision_id)

    latest = @revisions.first

    # if there is at least one revision available
    if latest
      meta = latest.fetch('meta', {})
      @native_id = meta['native-id']
      @provider_id = meta['provider-id']
      @num_granules = meta['granule-count']

      @old_revision = !@revision_id.nil? && meta['revision-id'].to_s != @revision_id.to_s ? true : false

      # set accept content-type as umm-json with our current umm-c version
      content_type = "application/#{Rails.configuration.umm_c_version}; charset=utf-8"
      # but if we are reverting, we should get the collection in it's native format, so set content-type appropriately
      content_type = 'application/metadata+xml; charset=utf-8' if params[:action] == 'revert'

      collection_response = cmr_client.get_concept(@concept_id, token, { 'Accept' => content_type }, @revision_id)

      if collection_response.success?
        @collection = collection_response.body
        @collection_format = collection_response.headers.fetch('content-type', '')
      else
        set_collection_error_data
      end
    else
      # concept wasn't found, CMR might be a little slow
      # Take the user to a blank page with a message the collection doesn't exist yet,
      # eventually auto refreshing the page would be cool
      set_collection_error_data
    end
  end

  def set_collection_error_data
    @collection = {}
    @collection_format = ''
    @error = 'This collection is not available. It is either being published right now, does not exist, or you have insufficient permissions to view this collection.'
  end

  def proposal_mode_enabled?
    if params['action'] == 'show'
      # actions available in both dMMT and MMT
      multi_mode_actions_allowed?
    elsif %w[create_delete_proposal create_update_proposal].include?(params['action'])
      # actions available in dMMT to users and approvers
      proposal_mode_all_user_actions_allowed?
    else
      # actions available in MMT
      super
    end
  end
end
