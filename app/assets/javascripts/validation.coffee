$(document).ready ->
  isMetadataForm = ->
    $('.metadata-form').length > 0

  isUmmForm = ->
    $('.umm-form').length > 0

  isUmmSForm = ->
    $('.umm-form.service-form').length > 0

  isUmmVarForm = ->
    $('.umm-form.variable-form').length > 0

  getPageJson = ->
    if isMetadataForm()
      json = JSON.parse($('.metadata-form').find('input, textarea, select').filter ->
        return this.value
      .serializeJSON()).Draft
    else if isUmmForm()
      json = $('.umm-form').find('input, textarea, select').filter ->
        return this.value
      json = JSON.parse(json.serializeJSON())
      if isUmmSForm()
        json = json.ServiceDraft?.Draft or {}
        fixServicesKeys(json)
      else if isUmmVarForm()
        json = json.VariableDraft?.Draft or {}
        fixAvgCompressionRates(json)

    json = {} unless json?

    fixNumbers(json)
    fixIntegers(json)
    fixNestedFields(json)

    return json

  # fix keys from the serialized page json that don't match the schema
  fixServicesKeys = (json) ->
    if isUmmSForm()
      # fix RelatedUrls to RelatedURLs
      if json?.RelatedUrls?
        json.RelatedURLs = json.RelatedUrls
        delete json.RelatedUrls
      # Operation Metadata has DataResourceDOI, CRSIdentifier, and UOMLabel
      # that need to be fixed
      if json?.OperationMetadata?
        for opData, i in json.OperationMetadata
          if opData?.CoupledResource?
            cResource = opData.CoupledResource

            if cResource.DataResourceDoi?
              cResource.DataResourceDOI = cResource.DataResourceDoi
              delete cResource.DataResourceDoi

            if cResource.DataResource?.DataResourceSpatialExtent?
              spExtent = cResource.DataResource.DataResourceSpatialExtent

              if spExtent.SpatialBoundingBox?.CrsIdentifier?
                spExtent.SpatialBoundingBox.CRSIdentifier = spExtent.SpatialBoundingBox.CrsIdentifier
                delete spExtent.SpatialBoundingBox.CrsIdentifier

              if spExtent.GeneralGrid?
                if spExtent.GeneralGrid.CrsIdentifier?
                  spExtent.GeneralGrid.CRSIdentifier = spExtent.GeneralGrid.CrsIdentifier
                  delete spExtent.GeneralGrid.CrsIdentifier
                if spExtent.GeneralGrid.Axis?
                  for ax in spExtent.GeneralGrid.Axis
                    if ax.Extent?.UomLabel?
                      ax.Extent.UOMLabel = ax.Extent.UomLabel
                      delete ax.Extent.UomLabel

  # This fixes AvgCompressionRateASCII and AvgCompressionRateNetCDF4 in the page json
  fixAvgCompressionRates = (json) ->
    if json?.SizeEstimation?.AvgCompressionRateAscii?
      json.SizeEstimation.AvgCompressionRateASCII = json.SizeEstimation.AvgCompressionRateAscii
      delete json.SizeEstimation.AvgCompressionRateAscii
    if json?.SizeEstimation?.AvgCompressionRateNetCdf4?
      json.SizeEstimation.AvgCompressionRateNetCDF4 = json.SizeEstimation.AvgCompressionRateNetCdf4
      delete json.SizeEstimation.AvgCompressionRateNetCdf4

  # Nested non-array fields don't display validation errors because there is no form field for the top level field
  # Adding an empty object into the json changes the validation to display errors on the missing subfields
  fixNestedFields = (json) ->
    if isMetadataForm()
      json?.ProcessingLevel = {} unless json?.ProcessingLevel?
    else if isUmmSForm()
      json?.RelatedURLs = [] unless json?.RelatedURLs?

  fixNumbers = (json) ->
    if isMetadataForm()
      numberFields = $('.mmt-number.validate').filter ->
        this.value
    else if isUmmForm()
      numberFields = $('.validate[number="true"]').filter ->
        this.value

    for element in numberFields
      name = $(element).attr('name')
      re = /\[(.*?)\]/g
      path = []
      value = json
      while match = re.exec name
        newPath = humps.pascalize(match[1])
        if isUmmForm()
          newPath = 'AvgCompressionRateASCII' if newPath == 'AvgCompressionRateAscii'
          newPath = 'AvgCompressionRateNetCDF4' if newPath == 'AvgCompressionRateNetCdf4'

        unless newPath == 'Draft'
          value = value[newPath]
          path.push newPath

      if $.isNumeric(value)
        updateJson(json, path, parseFloat(value))

    return

  fixIntegers = (json) ->
    if isMetadataForm()
      integerFields = $('.mmt-integer.validate').filter ->
        this.value
    else if isUmmForm()
      integerFields = $('.validate[integer="true"]').filter ->
        this.value

    for element in integerFields
      name = $(element).attr('name')
      re = /\[(.*?)\]/g
      path = []
      value = json
      while match = re.exec name
        newPath = humps.pascalize(match[1])
        unless newPath == 'Draft'
          value = value[newPath]
          path.push newPath

      if $.isNumeric(value) and Math.floor(value) == +value
        updateJson(json, path, parseInt(value))

    return

  updateJson = (json, path, value) ->
    tempJson = json
    index = 0
    while index < path.length - 1
      tempJson = tempJson[path[index]]
      index++

    tempJson[path[path.length - 1]] = value
    return

  validationMessages = (error) ->
    keyword = error.keyword
    if error.title.length > 0
      field =  error.title
    else
      path = error.dataPath.split('/')
      field = path[path.length - 1]
      field = path[path.length - 2] if $.isNumeric(field)
    type = getFieldType(error.element)

    switch keyword
      when 'required' then "#{field} is required"
      when 'maxLength' then "#{field} is too long"
      when 'minLength' then "#{field} is too short"
      when 'pattern' then "#{field} must match the provided pattern"
      when 'format'
        if type == 'URI'
          "#{field} is an invalid URI"
        else
          "#{field} is an incorrect format"
      when 'minItems' then "#{field} has too few items"
      when 'maxItems' then "#{field} has too many items"
      when 'type' then "#{field} must be of type #{type}"
      when 'maximum' then "#{field} is too high"
      when 'minimum' then "#{field} is too low"
      when 'parameter-range-later' then "#{field} must be later than Parameter Range Begin"
      when 'parameter-range-larger' then "#{field} must be larger than Parameter Range Begin"
      when 'oneOf' # TODO check and remove 'Party' - was only for organization or personnel
        # oneOf Party means it wants oneOf OrganizationName or Person
        # Those errors don't matter to a user because they don't see
        # that difference in the forms
        if field == 'Party'
          "Party is incomplete"
        else
          "#{field} should have one type completed"
      when 'invalidPicklist' then "#{field} #{error.message}"
      when 'enum' then "#{field} value [#{$('#' + error.id + ' option:selected').text()}] does not match a valid selection option"
      when 'anyOf' then "#{error.message}"
      # UseConstraintsType is the only place a 'not' validation is used
      # so this is a very specific message
      when 'not' then 'License Url and License Text cannot be used together'
      # In case of Average File Size is set but no Average File Size Unit was selected
      # and also in case of Total Collection File Size and Total Collection File Size Unit,
      # we only want this simple message instead of the raw message:
#     # 'should have property TotalCollectionFileSizeUnit when property TotalCollectionFileSize is present'
      when 'dependencies' then "#{field} is required"
      when 'not_unique' then "#{field} must be unique within a provider context"
      # Using an alternate keyword allows skipping some checks associated with
      # required fields that are problematic because the field is not in the schema
      # This error message should appear when a template name is not provided by the user
      when 'must_exist' then "#{field} is required"

  getFieldType = (element) ->
    classes = $(element).attr('class').split(/\s+/)
    if classes.indexOf('mmt-number') != -1 or $(element).attr('number') == 'true'
      type = 'number'
    if classes.indexOf('mmt-integer') != -1 or $(element).attr('integer') == 'true'
      type = 'integer'
    if classes.indexOf('mmt-boolean') != -1 or $(element).attr('boolean') == 'true'
      type = 'boolean'
    if classes.indexOf('mmt-date-time') != -1 or $(element).attr('date-time') == 'true'
      type = 'date-time'
    if classes.indexOf('mmt-uri') != -1 or $(element).attr('uri') == 'true'
      type = 'URI'
    if classes.indexOf('mmt-uuid') != -1 or $(element).attr('uuid') == 'true'
      type = 'uuid'
    type

  displayInlineErrors = (errors) ->
    for error in errors
      $element = $("##{error.id}")

      message = validationMessages(error)

      classes = 'eui-banner--danger validation-error'

      errorElement = $('<div/>',
        id: "#{error.id}_error"
        class: classes
        html: message
      )

      # if the error needs to be shown after the remove button
      if $element.parent().hasClass('multiple-item')
        afterElement = $element.parent().children('.remove')
      else
        afterElement = $element

      # if the error needs to be shown after the help icon
      if $element.next().hasClass('display-modal')
        afterElement = $element.next()

      # if the error needs to be shown after the select2
      if $element.next().hasClass('select2-container')
        afterElement = $element.next()

      $(errorElement).insertAfter(afterElement)

  displaySummary = (errors) ->
    # This modal is loaded on every new/edit page for templates, but not drafts
    resource_type = if $('#invalid-template-modal').length > 0 then 'template' else 'draft'
    summary = $('<div/>',
      class: 'eui-banner--danger summary-errors'
      html: "<h4><i class='fa fa-exclamation-triangle'></i> This #{resource_type} has the following errors:</h4>"
    )

    errorList = $('<ul/>', class: 'no-bullet')
    for error in errors
      message = validationMessages(error)
      listElement = $('<li/>')
      $('<a/>',
        href: "##{error.id}"
        text: message
      ).appendTo(listElement)
      $(listElement).appendTo(errorList)

    $(errorList).appendTo(summary)

    $(summary).insertAfter('.nav-top')

  getErrorDetails = (error) ->
    if error.keyword == 'additionalProperties'
      error = null
      return

    # If the error is a Geometry anyOf error
    if error.keyword == 'anyOf'
      # TODO figure out anyOf with new fields
      # debugger
      if error.dataPath.indexOf('Geometry') != -1
        error.message = 'At least one Geometry Type is required'
      else
        # anyOf errors are showing up in the data contacts form, but only when
        # there are other validation errors. as the error messages are duplicate
        # and don't have the specificity of the other error messages (or have
        # information useful to the user), it seems best to suppress these
        # more info at https://github.com/epoberezkin/ajv/issues/201#issuecomment-222544956
        error = null
        return

    # Hide individual required errors from an anyOf constraint
    # So we don't fill the form with errors that don't make sense to the user
    # Except ArchiveAndDistributionInformation has 'anyOf' constraint to the child element FileArchiveInformation and
    # FileDistributionInformation which have required field 'Format'
    if error.keyword == 'required' && error.schemaPath.indexOf('anyOf') != -1 && !(error.dataPath.indexOf('ArchiveAndDistributionInformation') > -1 && error.params['missingProperty'] == 'Format')
      error = null
      return

    # TODO if not already done above, figure out anyOf errors for new fields
    # TODO look into oneOf errors


    error.dataPath += "/#{error.params.missingProperty}" if error.params.missingProperty?

    path = for p in error.dataPath.replace(/^\//, '').split('/')
      p = p.replace(/(\w)(\d)$/, '$1_$2')
      humps.decamelize(p)
    path = path.join('_')

    # Fix the path for special case keys
    path = path.replace(/u_r_ls/g, 'urls')
    path = path.replace(/u_r_l/g, 'url')
    path = path.replace(/u_r_l_content_type/g, 'url_content_type')
    path = path.replace(/d_o_i/g, 'doi')
    path = path.replace(/i_s_b_n/g, 'isbn')
    path = path.replace(/i_s_o_topic_categories/g, 'iso_topic_categories')
    path = path.replace(/data_i_d/g, 'data_id')
    path = path.replace(/c_r_s_identifier/g, 'crs_identifier')
    path = path.replace(/u_o_m_label/g, 'uom_label')
    path = path.replace(/a_s_c_i_i/g, 'ascii')
    path = path.replace(/c_d_f_4/g, 'cdf4')
    error.path = path

    if isMetadataForm()
      id = "draft_#{path}"
    else if isUmmSForm()
      id = "service_draft_draft_#{path}"
    else if isUmmVarForm()
      id = "variable_draft_draft_#{path}"
    # remove last index from id for Roles errors
    if /roles_0$/.test(id)
      id = id.slice(0, id.length - 2)
    error.id = id
    error.element = $("##{id}")

    if id.indexOf('cdf4') >= 0
      labelFor = id
    else
      labelFor = id.replace(/(_)?\d+$/, "")

    error.title = $("label[for='#{labelFor}']").text()

    if error.title.length == 0 && error.element.closest('.multiple').hasClass('simple-multiple')
      # some Multi Item fields (arrays of simple values) in UMM-C drafts have one label tied to the first field
      error.title = $("label[for='#{labelFor}_0']").text()

    error

  validateParameterRanges = (errors) ->
    if $('#additional-attributes').length > 0
      $('.multiple.additional-attributes > .multiple-item').each (index, element) ->
        type = $(element).find('.additional-attribute-type-select').val()
        if type.length > 0
          $begin = $(element).find('.parameter-range-begin')
          $end = $(element).find('.parameter-range-end')
          beginValue = $begin.val()
          endValue = $end.val()

          if beginValue.length > 0 && endValue.length > 0 && beginValue >= endValue
            largerTypes = ['INT', 'FLOAT']
            keyword = 'parameter-range-later'
            keyword = 'parameter-range-larger' if largerTypes.indexOf(type) != -1
            newError =
              keyword: keyword,
              dataPath: "/AdditionalAttributes/#{index}/ParameterRangeEnd"
              params: {}
            errors.push newError

  validatePicklistValues = (errors) ->
    # the mmt-fake-enum class is added to the select fields that don't have enum
    # values in the UMM Schema. Those 'real' enums can generate the errors messages
    # we need to display through schema validation. 'Fake' enums need this method to
    # generate errors
    $('select.mmt-fake-enum > option:disabled:selected, select.mmt-fake-enum > optgroup > option:disabled:selected').each ->
      id = $(this).parents('select').attr('id')
      visitField(id)
      # TODO: add horizontal_resolution_processing_level_enum here?
      dataPath = switch
        when /processing_level_id/.test id
          '/ProcessingLevel/Id'
        when /metadata_language/.test id
          '/MetadataLanguage'
        when /data_language/.test id
          '/DataLanguage'
        when /draft_platforms_(\d*)_short_name/.test id
          [_, index] = id.match /platforms_(\d*)_short_name/
          "/Platforms/#{index}/ShortName"
        when /draft_platforms_(\d*)_instruments_(\d*)_short_name/.test id
          [_, index, index2] = id.match /platforms_(\d*)_instruments_(\d*)_short_name/
          "/Platforms/#{index}/Instruments/#{index2}/ShortName"
        when /draft_platforms_(\d*)_instruments_(\d*)_composed_of_(\d*)_short_name/.test id
          [_, index, index2, index3] = id.match /platforms_(\d*)_instruments_(\d*)_composed_of_(\d*)_short_name/
          "/Platforms/#{index}/Instruments/#{index2}/ComposedOf/#{index3}/ShortName"
        when /temporal_keywords/.test id
          '/TemporalKeywords'
        when /data_centers_\d*_short_name/.test id
          [_, index] = id.match /data_centers_(\d*)_short_name/
          "/DataCenters/#{index}/ShortName"
        when /data_centers_\d*_contact_information_addresses_\d*_country/.test id
          [_, index1, index2] = id.match /data_centers_(\d*)_contact_information_addresses_(\d*)_country/
          "/DataCenters/#{index1}/ContactInformation/Addresses/#{index2}/Country"
        when /data_centers_\d*_contact_information_addresses_\d*_state_province/.test id
          [_, index1, index2] = id.match /data_centers_(\d*)_contact_information_addresses_(\d*)_state_province/
          "/DataCenters/#{index1}/ContactInformation/Addresses/#{index2}/StateProvince"
        when /data_contacts_\d*_contact_person_data_center_short_name/.test id
          [_, index] = id.match /data_contacts_(\d*)_contact_person_data_center_short_name/
          "/DataContacts/#{index}/ContactPersonDataCenter/ShortName"
        when /data_contacts_\d*_contact_group_data_center_short_name/.test id
          [_, index] = id.match /data_contacts_(\d*)_contact_group_data_center_short_name/
          "/DataContacts/#{index}/ContactGroupDataCenter/ShortName"
        when /data_contacts_\d*_contact_person_data_center_contact_person_contact_information_addresses_\d*_country/.test id
          [_, index1, index2] = id.match /data_contacts_(\d*)_contact_person_data_center_contact_person_contact_information_addresses_(\d*)_country/
          "/DataContacts/#{index1}/ContactPersonDataCenter/ContactPerson/ContactInformation/Addresses/#{index2}/Country"
        when /data_contacts_\d*_contact_person_data_center_contact_person_contact_information_addresses_\d*_state_province/.test id
          [_, index1, index2] = id.match /data_contacts_(\d*)_contact_person_data_center_contact_person_contact_information_addresses_(\d*)_state_province/
          "/DataContacts/#{index1}/ContactPersonDataCenter/ContactPerson/ContactInformation/Addresses/#{index2}/StateProvince"
        when /data_contacts_\d*_contact_group_data_center_contact_group_contact_information_addresses_\d*_country/.test id
          [_, index1, index2] = id.match /data_contacts_(\d*)_contact_group_data_center_contact_group_contact_information_addresses_(\d*)_country/
          "/DataContacts/#{index1}/ContactGroupDataCenter/ContactGroup/ContactInformation/Addresses/#{index2}/Country"
        when /data_contacts_\d*_contact_group_data_center_contact_group_contact_information_addresses_\d*_state_province/.test id
          [_, index1, index2] = id.match /data_contacts_(\d*)_contact_group_data_center_contact_group_contact_information_addresses_(\d*)_state_province/
          "/DataContacts/#{index1}/ContactGroupDataCenter/ContactGroup/ContactInformation/Addresses/#{index2}/StateProvince"
        when /data_contacts_\d*_contact_person_contact_information_addresses_\d*_country/.test id
          [_, index1, index2] = id.match /data_contacts_(\d*)_contact_person_contact_information_addresses_(\d*)_country/
          "/DataContacts/#{index1}/ContactPerson/ContactInformation/Addresses/#{index2}/Country"
        when /data_contacts_\d*_contact_person_contact_information_addresses_\d*_state_province/.test id
          [_, index1, index2] = id.match /data_contacts_(\d*)_contact_person_contact_information_addresses_(\d*)_state_province/
          "/DataContacts/#{index1}/ContactPerson/ContactInformation/Addresses/#{index2}/StateProvince"
        when /data_contacts_\d*_contact_group_contact_information_addresses_\d*_country/.test id
          [_, index1, index2] = id.match /data_contacts_(\d*)_contact_group_contact_information_addresses_(\d*)_country/
          "/DataContacts/#{index1}/ContactGroup/ContactInformation/Addresses/#{index2}/Country"
        when /data_contacts_\d*_contact_group_contact_information_addresses_\d*_state_province/.test id
          [_, index1, index2] = id.match /data_contacts_(\d*)_contact_group_contact_information_addresses_(\d*)_state_province/
          "/DataContacts/#{index1}/ContactGroup/ContactInformation/Addresses/#{index2}/StateProvince"

      # Remove required error from the same dataPath
      errors = errors.filter (error) ->
        if error.keyword == 'required'
          dataPath.indexOf(error.dataPath) != -1
        else
          true

      error = {}
      error.keyword = 'invalidPicklist'
      error.message = "value [#{$(this).val()}] does not match a valid selection option"
      error.params = {}
      error.dataPath = dataPath
      errors.push error

    # combine TemporalKeywords invalidPicklist errors if more than one exist
    # find TemporalKeywords errors
    temporalKeywordErrors = errors.filter (error) ->
      error.dataPath == '/TemporalKeywords'

    if temporalKeywordErrors.length > 1
      # get all other errors
      errors = errors.filter (error) ->
        error.dataPath != '/TemporalKeywords'

      # combine temporalKeywordErrors into 1 error
      values = []
      for error in temporalKeywordErrors
        [_, value] = error.message.match /\[(.*)\]/
        values.push value

      newError = {}
      newError.keyword = 'invalidPicklist'
      newError.message = "values [#{values.join(', ')}] do not match a valid selection option"
      newError.params = {}
      newError.dataPath = '/TemporalKeywords'
      errors.push newError

    errors

  addIfNotAlready = (errorArray, newError) ->
    exist = false
    for error in errorArray
      if error.id == newError.id && error.keyword == newError.keyword
        exist = true
    if !exist && $("##{newError.id}").length > 0
      errorArray.push newError
    errorArray

  validatePage = (opts) ->
    $('.validation-error').remove()
    $('.summary-errors').remove()

    # Remove the disabled attribute from fields before we read data in
    # This allows invalid picklist options to be read in so the correct
    # error message is displayed
    disabledFields = $(':disabled').removeAttr('disabled')

    json = getPageJson()

    # put the disabled attribute back in
    disabledFields.attr('disabled', true)

    ajv = Ajv
      allErrors: true,
      jsonPointers: true,
      formats: 'uri' : URI_REGEX
    validate = ajv.compile(globalJsonSchema)
    validate(json)
    # debugger
    # adding validation for Data Contacts form with separate schema as it
    # does not follow UMM schema structure in the form
    # Data Contacts Schema is only passed on the data contacts form
    # validateDataContacts = ajv.compile(globalDataContactsFormSchema)
    if globalDataContactsFormSchema?
      validate = ajv.compile(globalDataContactsFormSchema)
      validate(json)

    errors = if validate.errors? then validate.errors else []
    # console.log 'errors! ', JSON.stringify(errors)

    validateParameterRanges(errors)
    errors = validatePicklistValues(errors)

    template_error = validateTemplateName(errors)

    inlineErrors = []
    summaryErrors = []

    # Display errors, from visited fields
    for error, index in errors
      if error = getErrorDetails error
        # does the error id match the visitedFields
        visited = visitedFields.filter (e) ->
          return e == error.id
        .length > 0

        if (visited or opts.showConfirm) and inlineErrors.indexOf(error) == -1
          # don't duplicate errors
          # Because ArchiveAndDistributionInformation has 'anyOf' child elements,
          # errors from the schema validator can be duplicated, so add an error to
          # the error arrays only if it is not already there
          # HorizontalDataResolutionType are 'oneOf' options that contain 'anyOf'
          # required items, so also creates duplicates of errors
          if error.id.match(/^draft_archive_and_distribution_information_/i) || error.id.match(/^draft_spatial_extent_horizontal_spatial_domain_resolution_and_coordinate_system_horizontal_data_resolutions/i)
            addIfNotAlready(inlineErrors, error)
            addIfNotAlready(summaryErrors, error)
          else
            inlineErrors.push error if $("##{error.id}").length > 0
            summaryErrors.push error if $("##{error.id}").length > 0

    # debugger
    if inlineErrors.length > 0 and opts.showInline
      displayInlineErrors inlineErrors
    if summaryErrors.length > 0 and opts.showSummary
      displaySummary summaryErrors
    if opts.showConfirm
      # 'visit' any invalid fields so they don't forget about their error
      for error in inlineErrors
        visitField(error.id)

    valid = summaryErrors.length == 0

    if template_error and opts.showConfirm
      $('#display-invalid-template-modal').click()
      $('#invalid-draft-deny').hide()
      $('#invalid-draft-accept').hide()
      return false
    else if !valid and opts.showConfirm
      # click on link to open modal
      $('#display-invalid-draft-modal').click()
      $('#invalid-draft-deny').show()
      $('#invalid-draft-accept').show()
      return false

    valid


  validateTemplateName = (errors) ->
    if $('#draft_template_name').length > 0
      error = null
      if $('#draft_template_name').val().length == 0
        error = { "id": 'draft_template_name', "title": 'Draft Template Name', "params": {}, 'dataPath': '/TemplateName', 'keyword': 'must_exist'}
      else if globalTemplateNames.indexOf($('#draft_template_name').val()) isnt -1
        error = { "id": 'draft_template_name', "title": 'Draft Template Name', "params": {}, 'dataPath': '/TemplateName', 'keyword': 'not_unique'}

      if error
        errors.push(error)
        return true
    false

  visitedFields = []
  visitField = (field_id) ->
    # If anything in UseConstraints shows up, 'visit' draft_use_constraints
    # so the 'not' validation will show up before clicking
    # submit (which 'visits' everything)
    if field_id.indexOf('draft_use_constraints') == 0
      visitedFields.push 'draft_use_constraints' unless visitedFields.indexOf('draft_use_constraints') != -1

    visitedFields.push field_id unless visitedFields.indexOf(field_id) != -1

    if field_id.match /^variable_draft_draft_characteristics_index_ranges_lat_range_/i
      latRangeParentId = 'variable_draft_draft_characteristics_index_ranges_lat_range'
      visitedFields.push latRangeParentId unless visitedFields.indexOf(latRangeParentId) != -1

    if field_id.match /^variable_draft_draft_characteristics_index_ranges_lon_range_/i
      lonRangeParentId = 'variable_draft_draft_characteristics_index_ranges_lon_range'
      visitedFields.push lonRangeParentId unless visitedFields.indexOf(lonRangeParentId) != -1

  validateFromFormChange = ->
    validatePage
      showInline: true
      showSummary: true
      showConfirm: false

  validateForNavigation = ->
    validatePage
      showInline: true
      showSummary: true
      showConfirm: true

  # Validate the whole page on page load
  if $('.metadata-form, .umm-form').length > 0
    # Do not display validation errors on page load if model errors are showing
    if $('.model-errors').length == 0
      # "visit" each field with a value on page load
      $('.validate').not(':disabled').filter ->
        return switch this.type
          when 'radio'
            # don't want to save fields that aren't translated into metadata
            this.name? and this.checked
          else
            this.value
      .each (index, element) ->
        visitField($(element).attr('id'))

      validateFromFormChange()

  # // set up validation call
  $('.metadata-form, .umm-form').on 'blur', '.validate', ->
    visitField($(this).attr('id'))
    # if the field is a datepicker, and the datepicker is still open, don't validate yet
    return if $(this).attr('type') == 'datetime' and $('.datepicker:visible').length > 0
    validateFromFormChange()

  # 'blur' functionality for select2 fields
  $('.metadata-form .select2-select, .umm-form .select2-select').on 'select2:open', (event) ->
    visitField($(this).attr('id'))

  $('.metadata-form, .umm-form').on 'click', '.remove', ->
    validateFromFormChange()

  $('.metadata-form, .umm-form').find('input[type="radio"], select').not('.next-section, .jump-to-section').on 'change', ->
    validateFromFormChange()

  $(document).on 'mmtValidate', ->
    validateFromFormChange()

  $('.metadata-form .next-section').on 'change', ->
    $('#new_form_name').val(this.value)

    if validateForNavigation()
      $('.metadata-form').submit()

  $('.umm-form .jump-to-section').on 'change', ->
    $('.jump-to-section').val($(this).val())

    if validateForNavigation()
      $('.umm-form').submit()

  $('.metadata-form .save-form, .umm-form .save-form').on 'click', (e) ->
    $('#commit').val($(this).val())

    return validateForNavigation()

  # Handle modal 'Yes', submit form
  $('#invalid-draft-accept').on 'click', ->
    $('.metadata-form, .umm-form').submit()

  # If a user clicks on Save/Done, then jump_to_section, #commit needs to be cleared
  # Handle modal 'No'
  $('#invalid-draft-deny').on 'click', ->
    $('#commit').val('')

  # would be nice to add an explanation or cite source of the regex
  URI_REGEX = /^(?:[A-Za-z][A-Za-z0-9+\-.]*:(?:\/\/(?:(?:[A-Za-z0-9\-._~!$&'()*+,;=:]|%[0-9A-Fa-f]{2})*@)?(?:\[(?:(?:(?:(?:[0-9A-Fa-f]{1,4}:){6}|::(?:[0-9A-Fa-f]{1,4}:){5}|(?:[0-9A-Fa-f]{1,4})?::(?:[0-9A-Fa-f]{1,4}:){4}|(?:(?:[0-9A-Fa-f]{1,4}:){0,1}[0-9A-Fa-f]{1,4})?::(?:[0-9A-Fa-f]{1,4}:){3}|(?:(?:[0-9A-Fa-f]{1,4}:){0,2}[0-9A-Fa-f]{1,4})?::(?:[0-9A-Fa-f]{1,4}:){2}|(?:(?:[0-9A-Fa-f]{1,4}:){0,3}[0-9A-Fa-f]{1,4})?::[0-9A-Fa-f]{1,4}:|(?:(?:[0-9A-Fa-f]{1,4}:){0,4}[0-9A-Fa-f]{1,4})?::)(?:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))|(?:(?:[0-9A-Fa-f]{1,4}:){0,5}[0-9A-Fa-f]{1,4})?::[0-9A-Fa-f]{1,4}|(?:(?:[0-9A-Fa-f]{1,4}:){0,6}[0-9A-Fa-f]{1,4})?::)|[Vv][0-9A-Fa-f]+\.[A-Za-z0-9\-._~!$&'()*+,;=:]+)\]|(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)|(?:[A-Za-z0-9\-._~!$&'()*+,;=]|%[0-9A-Fa-f]{2})*)(?::[0-9]*)?(?:\/(?:[A-Za-z0-9\-._~!$&'()*+,;=:@]|%[0-9A-Fa-f]{2})*)*|\/(?:(?:[A-Za-z0-9\-._~!$&'()*+,;=:@]|%[0-9A-Fa-f]{2})+(?:\/(?:[A-Za-z0-9\-._~!$&'()*+,;=:@]|%[0-9A-Fa-f]{2})*)*)?|(?:[A-Za-z0-9\-._~!$&'()*+,;=:@]|%[0-9A-Fa-f]{2})+(?:\/(?:[A-Za-z0-9\-._~!$&'()*+,;=:@]|%[0-9A-Fa-f]{2})*)*|)(?:\?(?:[A-Za-z0-9\-._~!$&'()*+,;=:@\/?]|%[0-9A-Fa-f]{2})*)?(?:\#(?:[A-Za-z0-9\-._~!$&'()*+,;=:@\/?]|%[0-9A-Fa-f]{2})*)?|(?:\/\/(?:(?:[A-Za-z0-9\-._~!$&'()*+,;=:]|%[0-9A-Fa-f]{2})*@)?(?:\[(?:(?:(?:(?:[0-9A-Fa-f]{1,4}:){6}|::(?:[0-9A-Fa-f]{1,4}:){5}|(?:[0-9A-Fa-f]{1,4})?::(?:[0-9A-Fa-f]{1,4}:){4}|(?:(?:[0-9A-Fa-f]{1,4}:){0,1}[0-9A-Fa-f]{1,4})?::(?:[0-9A-Fa-f]{1,4}:){3}|(?:(?:[0-9A-Fa-f]{1,4}:){0,2}[0-9A-Fa-f]{1,4})?::(?:[0-9A-Fa-f]{1,4}:){2}|(?:(?:[0-9A-Fa-f]{1,4}:){0,3}[0-9A-Fa-f]{1,4})?::[0-9A-Fa-f]{1,4}:|(?:(?:[0-9A-Fa-f]{1,4}:){0,4}[0-9A-Fa-f]{1,4})?::)(?:[0-9A-Fa-f]{1,4}:[0-9A-Fa-f]{1,4}|(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))|(?:(?:[0-9A-Fa-f]{1,4}:){0,5}[0-9A-Fa-f]{1,4})?::[0-9A-Fa-f]{1,4}|(?:(?:[0-9A-Fa-f]{1,4}:){0,6}[0-9A-Fa-f]{1,4})?::)|[Vv][0-9A-Fa-f]+\.[A-Za-z0-9\-._~!$&'()*+,;=:]+)\]|(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)|(?:[A-Za-z0-9\-._~!$&'()*+,;=]|%[0-9A-Fa-f]{2})*)(?::[0-9]*)?(?:\/(?:[A-Za-z0-9\-._~!$&'()*+,;=:@]|%[0-9A-Fa-f]{2})*)*|\/(?:(?:[A-Za-z0-9\-._~!$&'()*+,;=:@]|%[0-9A-Fa-f]{2})+(?:\/(?:[A-Za-z0-9\-._~!$&'()*+,;=:@]|%[0-9A-Fa-f]{2})*)*)?|(?:[A-Za-z0-9\-._~!$&'()*+,;=@]|%[0-9A-Fa-f]{2})+(?:\/(?:[A-Za-z0-9\-._~!$&'()*+,;=:@]|%[0-9A-Fa-f]{2})*)*|)(?:\?(?:[A-Za-z0-9\-._~!$&'()*+,;=:@\/?]|%[0-9A-Fa-f]{2})*)?(?:\#(?:[A-Za-z0-9\-._~!$&'()*+,;=:@\/?]|%[0-9A-Fa-f]{2})*)?)$/
