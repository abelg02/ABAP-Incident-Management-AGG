@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption View - Incident History'
@Metadata.allowExtensions: true
define view entity zc_dt_inct_h_agg
  as projection on zdd_inct_h_agg
{
  key HisUUID,
  key IncUUID,
      HisID,
      PreviousStatus,
      NewStatus,
      Text,
      LocalCreatedBy,
      LocalCreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      /* Associations */
      _Incident : redirected to parent zc_dt_inct_agg
}
