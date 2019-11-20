class ManageProposalController < ManageMetadataController
  before_action :mmt_approver_workflow_enabled?
  before_action :user_has_approver_permissions?

  RESULTS_PER_PAGE = 25

  def show
    @specified_url = 'manage_proposals'
    @providers = ['Select a provider to publish this record'] + current_user.available_providers

    # TODO: By the end of MMT-1916, this should no longer be necessary.
    # dMMT cannot verify a launchpad token and we do not consider launchpad
    # access to dMMT features to be MVP.
    if session[:access_token].blank?
      @proposals = []
      flash[:error] = 'Please log in with Earthdata Login to perform proposal approver actions in MMT.'
      return
    end

    sort_key, sort_dir = index_sort_order
    dmmt_response = cmr_client.dmmt_get_approved_proposals({}, token, request)

    if dmmt_response.success?
      Rails.logger.info("MMT successfully received approved proposals from dMMT at #{current_user.urs_uid}'s request.")

      proposals = if sort_key == 'user_name'
                    if sort_dir == 'ASC'
                      dmmt_response.body['proposals'].sort { |a, b| a['status_history'].fetch('submitted', {}).fetch('username', '') <=> b['status_history'].fetch('submitted', {}).fetch('username', '') }
                    else
                      dmmt_response.body['proposals'].sort { |a, b| b['status_history'].fetch('submitted', {}).fetch('username', '') <=> a['status_history'].fetch('submitted', {}).fetch('username', '') }
                    end
                  else
                    if sort_dir == 'ASC'
                      dmmt_response.body['proposals'].sort { |a, b| a[sort_key] <=> b[sort_key] }
                    else
                      dmmt_response.body['proposals'].sort { |a, b| b[sort_key] <=> a[sort_key] }
                    end
                  end
    else
      if unauthorized?(dmmt_response)
        flash[:error] = "Your token could not be authorized. Please try refreshing the page before contacting #{view_context.mail_to('support@earthdata.nasa.gov', 'Earthdata Support')} about #{request.uuid}."
        Rails.logger.error("#{request.uuid}: A user who was logged in with Non-NASA draft approver privileges was not authenticated or authorized correctly.  Refer to dMMT logs for further information: #{dmmt_response.body['request_id']}")
      else
        flash[:error] = "An internal error has occurred. Please contact #{view_context.mail_to('support@earthdata.nasa.gov', 'Earthdata Support')} about #{request.uuid} for further assitance."
        Rails.logger.error("#{request.uuid}: MMT has a bug or dMMT is not configured correctly.  Request to dMMT returned https code: #{dmmt_response.status}")
      end
      proposals = []
    end
    @proposals = Kaminari.paginate_array(proposals, total_count: proposals.count).page(params.fetch('page', 1)).per(RESULTS_PER_PAGE)
  end

  def publish_proposal
    proposal = JSON.parse(params['proposal_data'])

    # Delete and update requests should have the provider_id populated already
    provider = if proposal['request_type'] == 'create'
                 params['provider-publish-target']
               else
                 proposal['provider_id']
               end

    # Update and create requests are ingested on the same end point
    if proposal['request_type'] == 'delete'
      publish_delete_proposal(proposal, provider)
    else
      publish_create_or_update_proposal(proposal, provider)
    end

    redirect_to manage_proposals_path
  end

  private

  def index_sort_order
    @query = {}
    @query['sort_key'] = params['sort_key'] unless params['sort_key'].blank?

    if @query['sort_key']&.starts_with?('-')
      [@query['sort_key'].delete_prefix('-'), 'DESC']
    elsif @query['sort_key'].present?
      [@query['sort_key'], 'ASC']
    else
      ['updated_at', 'DESC']
    end
  end

  def user_has_approver_permissions?
    redirect_to manage_collections_path unless @user_has_approver_permissions
  end

  def unauthorized?(response)
    response.status == 401
  end

  def publish_delete_proposal(proposal, provider)
    search_response = cmr_client.get_collections({ 'native_id': proposal['native_id'] }, token)

    if search_response.body['hits'].to_s != '1'
      # If the search has more than one hit or 0 hits, the record was not
      # uniquely identified from it's native ID.
      flash[:error] = I18n.t('controllers.manage_proposals.publish.flash.delete.not_found_error')
      Rails.logger.info("Could not complete delete request from proposal with short name: #{proposal['short_name']} and id: #{proposal['id']} because it could not be located.")
    elsif !search_response.body['items'][0]['meta']['granule-count'].zero?
      # Do not allow the deletion of collections which have granules
      flash[:error] = I18n.t('controllers.manage_proposals.publish.flash.delete.granules_error')
      Rails.logger.info("Could not complete delete request from proposal with short name: #{proposal['short_name']} and id: #{proposal['id']} because it had granules at the time of the delete attempt.")
    else
      cmr_response = cmr_client.delete_collection(provider, proposal['native_id'], token)

      if cmr_response.success?
        flash[:success] = I18n.t('controllers.manage_proposals.publish.flash.delete.success')
        Rails.logger.info("Proposal with short name: #{proposal['short_name']} and id: #{proposal['id']} were successfully deleted in the CMR")
      else
        flash[:error] = I18n.t('controllers.manage_proposals.publish.flash.delete.error')
        Rails.logger.info("Proposal with short name: #{proposal['short_name']} and id: #{proposal['id']} could not be deleted in the CMR")
      end
    end
  end

  def publish_create_or_update_proposal(proposal, provider)
    cmr_response = cmr_client.ingest_collection(proposal['draft'].to_json, provider, proposal['native_id'], token)

    if cmr_response.success?
      flash[:success] = I18n.t('controllers.manage_proposals.publish.flash.create.success')
      Rails.logger.info("Proposal with short name: #{proposal['short_name']} and id: #{proposal['id']} were successfully ingested into the CMR")
    else
      puts cmr_response.errors.inspect
      flash[:error] = I18n.t('controllers.manage_proposals.publish.flash.create.error')
      Rails.logger.info("Proposal with short name: #{proposal['short_name']} and id: #{proposal['id']} could not be ingested into the CMR. The CMR provided the following reasons: #{cmr_response.errors.inspect}")
    end
  end
end