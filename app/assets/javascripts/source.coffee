$(document).on 'change', '#typeSelector', ->
  visibleConfig = $('#configTarget .configBlock')
  selected = $('#sourceType' + $(this).val())
  $('#configForms').append visibleConfig
  $('#configTarget').append selected