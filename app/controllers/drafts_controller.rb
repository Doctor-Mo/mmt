class DraftsController < ApplicationController
  before_action :set_draft, only: [:show, :edit, :update, :destroy, :publish]
  before_action :load_umm_schema, except: [:subregion_options]
  before_filter :ensure_correct_draft_provider, only: [:edit, :show]

  # GET /drafts
  # GET /drafts.json
  def index
    @drafts = @current_user.drafts.where(provider_id: @current_user.provider_id)
                                  .order('updated_at DESC')
  end

  # GET /drafts/1
  # GET /drafts/1.json
  def show
    @language_codes = cmr_client.get_language_codes
    @errors = validate_metadata
  end

  # GET /drafts/new
  def new
    @draft = Draft.new(user: @current_user, draft: {}, id: 0)
    render :show
  end

  # GET /drafts/1/edit
  def edit
    if params[:form]
      @draft_form = params[:form]
      set_science_keywords
      set_spatial_keywords
      set_platform_types
      set_language_codes
      set_country_codes
      set_temporal_keywords
      set_organizations
    else
      render action: 'show'
    end
  end

  # PATCH/PUT /drafts/1
  # PATCH/PUT /drafts/1.json
  def update
    if params[:id] == '0'
      @draft = Draft.create(user: @current_user, provider_id: @current_user.provider_id, draft: {})
      params[:id] = @draft.id
    else
      @draft = Draft.find(params[:id])
    end

    if @draft.update_draft(params[:draft])
      flash[:success] = 'Draft was successfully updated.'

      case params[:commit]
      when 'Save & Done'
        redirect_to @draft
      when 'Save & Next'
        # Determine next form to go to
        next_form_name = Draft.get_next_form(params['next_section'])
        redirect_to draft_edit_form_path(@draft, next_form_name)
      else # Jump directly to a form
        next_form_name = params['new_form_name']
        redirect_to draft_edit_form_path(@draft, next_form_name)
      end
    else # record update failed
      # render 'edit' # this should get @draft_form
      # Remove
      flash[:error] = 'Draft was not updated successfully.'
      redirect_to @draft
    end
  end

  # DELETE /drafts/1
  # DELETE /drafts/1.json
  def destroy
    # if new_record?, no need to destroy
    @draft.destroy unless @draft.new_record?
    respond_to do |format|
      flash[:success] = 'Draft was successfully deleted.'
      format.html { redirect_to manage_metadata_path }
    end
  end

  def publish
    @draft.add_metadata_dates

    draft = @draft.draft

    ingested = cmr_client.ingest_collection(draft.to_json, @draft.provider_id, @draft.native_id, token)

    if ingested.success?
      # Delete draft
      @draft.destroy

      xml = MultiXml.parse(ingested.body)
      concept_id = xml['result']['concept_id']
      revision_id = xml['result']['revision_id']
      flash[:success] = 'Draft was successfully published.'
      redirect_to collection_path(concept_id, revision_id: revision_id)
    else
      # Log error message
      Rails.logger.error("Ingest Metadata Error: #{ingested.inspect}")

      @ingest_errors = generate_ingest_errors(ingested)

      flash[:error] = 'Draft was not published successfully.'
      render :show
    end
  end

  def subregion_options
    render partial: 'drafts/forms/fields/subregion_select'
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_draft
    id = params[:draft_id] || params[:id]
    if id == '0'
      @draft = Draft.new(user: @current_user, draft: {}, id: 0)
    else
      @draft = Draft.find(id)
    end
    @draft_forms = Draft::DRAFT_FORMS
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def draft_params
    params.require(:draft).permit(:user_id, :draft)
  end

  def load_umm_schema
    @json_schema = JSON.parse(File.read(File.join(Rails.root, 'lib', 'assets', 'schemas', 'umm-c-merged.json')))
  end

  def ensure_correct_draft_provider
    return if @draft.provider_id == @current_user.provider_id || @draft.new_record?

    @draft_action = request.original_url.include?('edit') ? 'edit' : 'view'
    @draft_form = params[:form] ? params[:form] : nil

    if @current_user.available_providers.include?(@draft.provider_id)
      @user_permissions = 'wrong_provider'
    else
      @user_permissions = 'none'
    end
    render :show
  end

  # These errors are generated by our JSON Schema validation
  def generate_show_errors(string)
    fields = string.match(/'#\/(.*?)'/).captures.first

    if string.include? 'did not contain a required property'
      required_field = string.match(/contain a required property of '(.*)'/).captures.first

      top_field = fields.split('/')[0] || required_field

      {
        field: required_field,
        top_field: top_field,
        page: get_page(top_field),
        error: 'is required'
      }

    # If the error is not about required fields
    else
      # if the last field is an array index, use the last section of the field path that isn't a number
      field = fields.split('/').select do |f|
        begin
          false if Float(f)
        rescue
          true
        end
      end
      {
        field: field.last,
        top_field: field[0],
        page: get_page(field[0]),
        error: get_error(string)
      }
    end
  end

  def get_error(error)
    case error
    when /maximum string length/
      'is too long'
    when /maximum value/
      'is too high'
    when /must be a valid RFC3339 date\/time string/
      'is an invalid date format'
    when /did not match the regex/
      'is an invalid format'
    when /must be a valid URI/
      'is an invalid URI'
    when /larger than/
      'is larger than ParameterRangeBegin'
    end
  end

  def validate_parameter_ranges(errors, metadata)
    if metadata['AdditionalAttributes']
      metadata['AdditionalAttributes'].each do |attribute|
        non_range_types = %w(STRING BOOLEAN)
        unless non_range_types.include?(attribute['DataType'])
          range_begin = attribute['ParameterRangeBegin']
          range_end = attribute['ParameterRangeEnd']

          if range_begin && range_end && range_begin >= range_end
            error = "The property '#/AdditionalAttributes/0/ParameterRangeBegin' was larger than ParameterRangeEnd"
            errors << error
          end
        end
      end
    end

    errors
  end

  def validate_metadata
    schema = 'lib/assets/schemas/umm-c-json-schema.json'

    # Setup URI and date-time validation correctly
    uri_format_proc = lambda do |value|
      raise JSON::Schema::CustomFormatError.new('must be a valid URI') unless value.match URI_REGEX
    end
    JSON::Validator.register_format_validator('uri', uri_format_proc)
    date_time_format_proc = lambda do |value|
      raise JSON::Schema::CustomFormatError.new('must be a valid RFC3339 date/time string') unless value.match DATE_TIME_REGEX
    end
    JSON::Validator.register_format_validator('date-time', date_time_format_proc)

    errors = Array.wrap(JSON::Validator.fully_validate(schema, @draft.draft))
    errors = validate_parameter_ranges(errors, @draft.draft)
    errors.map { |error| generate_show_errors(error) }.flatten
  end

  def set_science_keywords
    @science_keywords = cmr_client.get_controlled_keywords('science_keywords') if params[:form] == 'descriptive_keywords'
  end

  def set_spatial_keywords
    @spatial_keywords = cmr_client.get_controlled_keywords('spatial_keywords') if params[:form] == 'spatial_information'
  end

  def set_platform_types
    @platform_types = cmr_client.get_controlled_keywords('platforms')['category'].map { |category| category['value'] }.sort if params[:form] == 'acquisition_information'
  end

  def set_language_codes
    if params[:form] == 'metadata_information' || params[:form] == 'collection_information'
      @language_codes = cmr_client.get_language_codes
    end
  end

  def set_country_codes
    # put the US at the top of the country list
    country_codes = Carmen::Country.all.sort
    united_states = country_codes.delete(Carmen::Country.named('United States'))
    @country_codes = country_codes.unshift(united_states)
  end

  def set_temporal_keywords
    if params[:form] == 'temporal_information'
      keywords = cmr_client.get_controlled_keywords('temporal_keywords')['temporal_resolution_range']
      @temporal_keywords = keywords.map { |keyword| keyword['value'] }
    end
  end

  def get_organization_short_names_long_names_urls(json, trios = [])
    json.each do |k, value|
      if k == 'short_name'
        value.each do |value2|
          short_name = value2['value']

          if value2['long_name'].nil?
            long_name = nil
            url = nil
          else
            long_name_hash = value2['long_name'][0]
            long_name = long_name_hash['value']
            url = long_name_hash['url'].nil? ? nil : long_name_hash['url'][0]['value']
          end

          trios.push [short_name, long_name, url]
        end

      elsif value.class == Array
        value.each do |value2|
          get_organization_short_names_long_names_urls value2, trios if value2.class == Hash
        end
      elsif value.class == Hash
        get_organization_short_names_long_names_urls value, trios
      end
    end
    trios
  end

  def set_organizations
    if params[:form] == 'organizations' || params[:form] == 'personnel'
      organizations = cmr_client.get_controlled_keywords('providers')
      organizations = get_organization_short_names_long_names_urls(organizations)
      @organizations = organizations.sort
    end
  end
end
