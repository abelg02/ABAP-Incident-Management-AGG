@EndUserText.label: 'Parameters for Change Status Action'
define abstract entity zdd_change_status_param_agg
{
  @EndUserText.label: 'New Status'
  @Consumption.valueHelpDefinition: [ {
      entity.name: 'zdd_status_vh_agg',
      entity.element: 'StatusCode',
      useForValidation: true
  } ]
  status : zde_status2_agg;

  @EndUserText.label: 'Observation'
  text   : zde_text_agg;
}
