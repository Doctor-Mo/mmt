$(document).ready ->
  # Handle geometry-picker (points/rectangles/polygons/lines)
  $('.geometry-picker').change ->
    $fields = $(this).siblings('div.geometry-fields')
    if this.checked
      # Show fields
      $fields.show()
    else
      # clear and hide fields
      $fields.hide()
      $.each $fields.find('input'), (index, field) ->
        $(field).val ''

  # Handle coordinate-system-picker (geographic/local)
  $('.coordinate-system-picker').change ->
    coordinateSystemType = $(this).parents('.coordinate-system-type')
    switch $(this).val()
      when 'geographic'
        $(coordinateSystemType).siblings('.geographic-coordinate-system-fields').show()
        $(coordinateSystemType).siblings('.local-coordinate-system-fields').hide()
      when 'local'
        $(coordinateSystemType).siblings('.geographic-coordinate-system-fields').hide()
        $(coordinateSystemType).siblings('.local-coordinate-system-fields').show()

    # Clear all fields
    $.each $(coordinateSystemType).siblings('.geographic-coordinate-system-fields, .local-coordinate-system-fields').find('input, select'), (index, field) ->
      $(field).val ''

    # Toggle checkboxes
    $(this).siblings('.coordinate-system-picker').prop 'checked', false
    $(this).prop 'checked', true

  # Handle TemporalRangeType selector
  $('.temporal-range-type-select').change ->
    $parent = $(this).parents('.temporal-range-type-group')
    $parent.siblings('.temporal-range-type').hide()

    # Clear all fields
    $parent.siblings('.temporal-range-type').find('input, select').val ''

    # Clear temporal-range-type-select radio buttons
    # that aren't the one just selected
    $parent.find('input').not("##{$(this).attr('id')}").prop 'checked', false

    # show the selected fields
    switch $(this).val()
      when 'SingleDateTime'
        $parent.siblings('.temporal-range-type.single-date-time').show()
      when 'RangeDateTime'
        $parent.siblings('.temporal-range-type.range-date-time').show()
      when 'PeriodicDateTime'
        $parent.siblings('.temporal-range-type.periodic-date-time').show()

  # Handle SpatialCoverageType selector
  $('.spatial-coverage-type-select').change ->
    $parent = $(this).parents('.spatial-coverage-type-group')

    $parent.siblings('.spatial-coverage-type').hide()

    # Clear all fields
    $parent.siblings('.spatial-coverage-type').find('input, select').not('input[type="radio"]').val ''

    # Clear radio buttons
    $parent.siblings('.spatial-coverage-type').find('input[type="radio"]').prop 'checked', false

    # Hide geographic and local coordinate system fields
    $parent.siblings().find('.geographic-coordinate-system-fields').hide()
    $parent.siblings().find('.local-coordinate-system-fields').hide()

    switch $(this).val()
      when 'HORIZONTAL'
        $parent.siblings('.spatial-coverage-type.horizontal').show()
      when 'VERTICAL'
        $parent.siblings('.spatial-coverage-type.vertical').show()
      when 'ORBITAL'
        $parent.siblings('.spatial-coverage-type.orbit').show()
      when 'HORIZONTAL_VERTICAL'
        $parent.siblings('.spatial-coverage-type.horizontal').show()
        $parent.siblings('.spatial-coverage-type.vertical').show()
      when 'ORBITAL_VERTICAL'
        $parent.siblings('.spatial-coverage-type.orbit').show()
        $parent.siblings('.spatial-coverage-type.vertical').show()
      when 'BOTH'
        $parent.siblings('.spatial-coverage-type.horizontal').show()
        $parent.siblings('.spatial-coverage-type.vertical').show()

  # Handle global spatial checkbox
  $('.spatial-coverage-type.horizontal').on 'click', 'a.global-coverage', ->
    $fields = $(this).parent().siblings('.compass-coordinates')
    $fields.find('.bounding-rectangle-point.west').val('-180')
    $fields.find('.bounding-rectangle-point.east').val('180')
    $fields.find('.bounding-rectangle-point.north').val('90')
    $fields.find('.bounding-rectangle-point.south').val('-90')
    $fields.find('.bounding-rectangle-point.south').trigger('change')

  # Handle Data Contacts Type selector
  $('.data-contact-type-select').change ->
    $contactTypeSelect = $(this).parents('.data-contact-type-select-parent')
    $dataContactTypes = $contactTypeSelect.siblings('.data-contact-type')
    # hide all the form elements
    $dataContactTypes.hide()
    # clear fieldset
    $dataContactTypes.find('input, select').val ''
    # disable form elements so blank values dont interfere with saving
    $dataContactTypes.find('input, select').prop 'disabled', true

    switch $(this).val()
      # show and enable selected data contact type
      when 'DataCenterContactPerson'
        $contactTypeSelect.siblings('.data-contact-type.data-center-contact-person').show()
        $contactTypeSelect.siblings('.data-contact-type.data-center-contact-person').find('input, select').prop 'disabled', false
      when 'DataCenterContactGroup'
        $contactTypeSelect.siblings('.data-contact-type.data-center-contact-group').show()
        $contactTypeSelect.siblings('.data-contact-type.data-center-contact-group').find('input, select').prop 'disabled', false
      when 'NonDataCenterContactPerson'
        $contactTypeSelect.siblings('.data-contact-type.non-data-center-contact-person').show()
        $contactTypeSelect.siblings('.data-contact-type.non-data-center-contact-person').find('input, select').prop 'disabled', false
      when 'NonDataCenterContactGroup'
        $contactTypeSelect.siblings('.data-contact-type.non-data-center-contact-group').show()
        $contactTypeSelect.siblings('.data-contact-type.non-data-center-contact-group').find('input, select').prop 'disabled', false

  # Clear radio button selection and hide content
  $('.clear-radio-button').on 'click', ->
    $fieldset = $(this).parents('fieldset')
    content = $(this).data('content')

    $(this).siblings().find('input, select, textarea').not('input[type="radio"]').val ''
    $fieldset.find(".#{content}-group input[type='radio']").prop 'checked', false
    $fieldset.find(".#{content} input[type='radio']").prop 'checked', false

    $fieldset.find(".#{content} .geometry-type").hide()

    $fieldset.find(".#{content}").hide()

  enableField = (field) ->
    $(field).prop 'disabled', false
    $(field).removeClass('disabled')

  disableField = (field) ->
    $(field).prop 'disabled', true
    $(field).addClass('disabled')

  # Handle RelatedURL URLContentType select
  $('.related-url-content-type-select').change ->
    handleContentTypeSelect($(this))

  # Handle RelatedURL Type select
  $('.related-url-type-select').change ->
    handleTypeSelect($(this))

  getRelatedUrlContentTypeSelect = (selector) ->
    $(selector).closest('.eui-accordion__body').find('.related-url-content-type-select')

  getRelatedUrlTypeSelect = (selector) ->
    $(selector).closest('.eui-accordion__body').find('.related-url-type-select')

  getRelatedUrlSubtypeSelect = (selector) ->
    $(selector).closest('.eui-accordion__body').find('.related-url-subtype-select')

  handleContentTypeSelect = (selector) ->
    contentTypeValue = $(selector).val()

    $typeSelect = getRelatedUrlTypeSelect(selector)
    $subtypeSelect = getRelatedUrlSubtypeSelect(selector)

    disableField($typeSelect)
    disableField($subtypeSelect)

    typeValue = $typeSelect.val()
    subtypeValue = $subtypeSelect.val()

    $typeSelect.find('option').remove()
    $typeSelect.append($("<option />").val('').text('Select Type'))

    if contentTypeValue?.length > 0
      types = urlContentTypeMap[contentTypeValue]?.types

      for k, v of types
        $typeSelect.append($("<option />").val(k).text(v.text))
        $typeSelect.val(typeValue) if typeValue == k

      # if only one Type option exists, select that option
      if $typeSelect.find('option').length == 2
        $typeSelect.find('option').first().remove()
        $typeSelect.find('option').first().prop 'selected', true
      enableField($typeSelect)
    $typeSelect.trigger('change')

  handleTypeSelect = (selector) ->
    typeValue = $(selector).val()

    $parent = $(selector).closest('.eui-accordion__body')
    $parent.find('.get-data-fields, .get-service-fields').hide()

    if typeValue?.length > 0
      switch typeValue
        when 'GET DATA'
          $parent.find('.get-data-fields').show()
          $parent.find('.get-service-fields').find('input, select').val ''
        when 'GET SERVICE'
          $parent.find('.get-service-fields').show()
          $parent.find('.get-data-fields').find('input, select').val ''

      $subtypeSelect = getRelatedUrlSubtypeSelect(selector)
      contentTypeValue = getRelatedUrlContentTypeSelect(selector).val()
      subtypeValue = $subtypeSelect.val()

      disableField($subtypeSelect)

      subtypes = urlContentTypeMap[contentTypeValue].types[typeValue].subtypes

      $subtypeSelect.find('option').remove()
      $subtypeSelect.append($("<option />").val('').text('Select Subtype'))
      for subtype in subtypes
        $subtypeSelect.append($("<option />").val(subtype[1]).text(subtype[0]))
        $subtypeSelect.val(subtypeValue) if subtypeValue == subtype[1]

      # if only one Subtype option exists, select that option
      if $subtypeSelect.find('option').length == 2
        $subtypeSelect.find('option').first().remove()
        $subtypeSelect.find('option').first().prop 'selected', true

      # Enable the field if any options exist
      else if $subtypeSelect.find('option').length > 1
        enableField($subtypeSelect)
      else
        # if no options exist
        $subtypeSelect.find('option').text 'No available subtype'
        $subtypeSelect.find('option').first().prop 'selected', true

  # Update all the url content type select fields on page load
  $('.related-url-content-type-select').each ->
    handleContentTypeSelect($(this))

  # Handle AdditionalAttributes type select
  $('#additional-attributes').on 'change', '.additional-attribute-type-select', ->
    handleAdditionAttributeDataType($(this))

  handleAdditionAttributeDataType = (element) ->
    value = $(element).val()
    $parent = $(element).parents('.multiple-item')
    $begin = $parent.find('.parameter-range-begin')
    $end = $parent.find('.parameter-range-end')

    disabledValues = ['STRING', 'BOOLEAN']
    if disabledValues.indexOf(value) != -1
      disableField($begin)
      disableField($end)
    else
      enableField($begin)
      enableField($end)

  $('.additional-attribute-type-select').each ->
    handleAdditionAttributeDataType($(this))

  ###
  # UMM-S Forms
  ###

  handleCoverageSpatialTypeSelect = (element) ->
    $parent = $(element).parents('.data-resource-spatial-group')

    # hide the spatial extent forms
    $parent.find('.data-resource-spatial-extent').hide()

    # if no type is selected, we should hide the extent group that contains a duplicate label
    $extentGroup = $parent.find('.data-resource-spatial-extent-group')
    if $(element).val() == '' then $extentGroup.hide() else $extentGroup.show()

    # show the form selected
    switch $(element).val()
      when 'SPATIAL_POINT'
        $parent.find('.data-resource-spatial-extent.spatial-points').show()
      when 'SPATIAL_LINE_STRING'
        $parent.find('.data-resource-spatial-extent.spatial-line-strings').show()
      when 'BOUNDING_BOX'
        $parent.find('.data-resource-spatial-extent.spatial-bounding-box').show()
      when 'GENERAL_GRID'
        $parent.find('.data-resource-spatial-extent.general-grid').show()
      when 'SPATIAL_POLYGON'
        $parent.find('.data-resource-spatial-extent.spatial-polygons').show()

    # Clear all hidden fields
    $parent.find('.data-resource-spatial-extent:hidden').find('input, select').val ''

  # Handle SpatialCoverageType selector
  $('.data-resource-spatial-type-select').change ->
    handleCoverageSpatialTypeSelect($(this))

  handleCoverageSpatialTypeSelect($('.data-resource-spatial-type-select'))

  # Handle DOI Available selector
  $('.doi-available-select').change ->
    $parent = $(this).parents('.doi-group')
    $parent.find('.doi-fields').hide()

    # Clear all fields
    $parent.find('.doi-fields').find('input, select, textarea').val ''

    # Clear doi-available-select radio buttons
    # that aren't the one just selected
    $parent.find('input').not("##{$(this).attr('id')}").prop 'checked', false

    # show the selected fields
    switch $(this).val()
      when 'Available'
        $parent.find('.doi-fields.available').show()
      when 'NotAvailable'
        $parent.find('.doi-fields.not-available').show()
        $parent.find('.doi-fields.not-available select').val('Not Applicable')

  # Handle Total Collection File Size Selector (in Archive and Distribution Information)
  $('.total-collection-file-size-select').change ->
    $parent = $(this).parents('.total-collection-file-size-group')
    $parent.find('.total-collection-file-size-fields').hide()

    # Clear all fields
    $parent.find('.total-collection-file-size-fields').find('input, select, textarea').val ''

    # Clear collection file size radio buttons
    # that aren't the one just selected
    $parent.find('input').not("##{$(this).attr('id')}").prop 'checked', false

    # show the selected fields
    switch $(this).val()
      when 'BySize'
        $parent.find('.total-collection-file-size-fields.by-size').show()
      when 'ByDate'
        $parent.find('.total-collection-file-size-fields.by-date').show()
        $parent.find('.total-collection-file-size-fields.by-date select').val('Not Applicable')
