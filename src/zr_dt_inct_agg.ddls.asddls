@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@EndUserText.label: 'Incident Root View'
define root view entity zr_dt_inct_agg
  as select from zdt_inct_agg
  composition [0..*] of zdd_inct_h_agg as _History
{
  key inc_uuid              as IncUUID,
      incident_id           as IncidentID,
      title                 as Title,
      description           as Description,
      status                as Status,
      priority              as Priority,
      creation_date         as CreationDate,
      changed_date          as ChangedDate,
      responsible_user      as ResponsibleUser,
      @Semantics.user.createdBy: true
      local_created_by      as LocalCreatedBy,
      @Semantics.systemDateTime.createdAt: true
      local_created_at      as LocalCreatedAt,
      @Semantics.user.localInstanceLastChangedBy: true
      local_last_changed_by as LocalLastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,

      _History
}
