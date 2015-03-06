# Set up an event handler that triggers when the type selector is changed on
# the new site form. The handler ensures the form displays the correct fields
# for the selected source type.
$(document).on 'change', '#typeSelector', ->
  visibleConfig = $('#configTarget .configBlock')
  selected = $('#sourceType' + $(this).val())
  $('#configForms').append visibleConfig
  $('#configTarget').append selected