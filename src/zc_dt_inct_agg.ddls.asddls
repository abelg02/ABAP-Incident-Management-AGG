@Metadata.allowExtensions: true
@EndUserText.label: 'Consumption View - Incidents'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define root view entity zc_dt_inct_agg
  provider contract transactional_query
  as projection on zr_dt_inct_agg
{
  key IncUUID,
      IncidentID,
      Title,
      Description,
      Status,
      Priority,
      CreationDate,
      ChangedDate,
      ResponsibleUser,
      LocalCreatedBy,
      LocalCreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      /* Associations */
      _History : redirected to composition child zc_dt_inct_h_agg
}
