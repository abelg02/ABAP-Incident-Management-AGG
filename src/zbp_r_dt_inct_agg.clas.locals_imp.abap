CLASS lhc_Incident DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Incident RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Incident RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Incident RESULT result.

    METHODS changeStatus FOR MODIFY
      IMPORTING keys FOR ACTION Incident~changeStatus RESULT result.

    METHODS setHistory FOR MODIFY
      IMPORTING keys FOR ACTION Incident~setHistory.

    METHODS setDefaultValues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Incident~setDefaultValues.

    METHODS setDefaultHistory FOR DETERMINE ON SAVE
      IMPORTING keys FOR Incident~setDefaultHistory.

    METHODS validateDates FOR VALIDATE ON SAVE
      IMPORTING keys FOR Incident~validateDates.

    METHODS validateDeleteStatus FOR VALIDATE ON SAVE
      IMPORTING keys FOR Incident~validateDeleteStatus.

    METHODS validateMandatoryFields FOR VALIDATE ON SAVE
      IMPORTING keys FOR Incident~validateMandatoryFields.

ENDCLASS.

CLASS lhc_Incident IMPLEMENTATION.

  METHOD get_instance_features.
  ENDMETHOD.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD changeStatus.

    " Leer datos actuales
    READ ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
      ENTITY Incident
      FIELDS ( Status IncUUID )
      WITH CORRESPONDING #( keys )
      RESULT DATA(incidents).

    " Obtener parámetro de acción
    DATA(ls_key) = VALUE #( keys[ %tky = incidents[ 1 ]-%tky ] OPTIONAL ).

    " 1. UPDATE masivo (fuera del loop lógico)
    MODIFY ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
      ENTITY Incident
      UPDATE
      SET FIELDS WITH VALUE #(
        FOR incident IN incidents
        ( %tky        = incident-%tky
          Status      = ls_key-%param-status
          ChangedDate = cl_abap_context_info=>get_system_date( ) )
      ).

    " 2. Crear historial separado (RAP clean)
    MODIFY ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
      ENTITY Incident
      CREATE BY \_History
      FIELDS ( HisID PreviousStatus NewStatus Text )
      WITH VALUE #(
        FOR incident IN incidents
        ( %tky = incident-%tky
          %target = VALUE #(
            ( %cid           = |HIST_{ incident-IncUUID }|
              HisID          = 1
              PreviousStatus = incident-Status
              NewStatus      = ls_key-%param-status
              Text           = ls_key-%param-text )
          )
        )
      ).

  ENDMETHOD.

  METHOD setHistory.
  ENDMETHOD.

  METHOD setDefaultValues.

    MODIFY ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
      ENTITY Incident
        UPDATE
        FIELDS ( Status CreationDate ChangedDate )
        WITH VALUE #(
          FOR key IN keys
          ( %tky = key-%tky
            Status = 'NE'
            CreationDate = cl_abap_context_info=>get_system_date( )
            ChangedDate = cl_abap_context_info=>get_system_date( ) )
        ).

  ENDMETHOD.

  METHOD setDefaultHistory.
  ENDMETHOD.

  METHOD validateDates.
  ENDMETHOD.

  METHOD validateDeleteStatus.
  ENDMETHOD.

  METHOD validateMandatoryFields.

    READ ENTITIES OF zr_dt_inct_agg IN LOCAL MODE
      ENTITY Incident
        FIELDS ( Title Description Priority )
        WITH CORRESPONDING #( keys )
      RESULT DATA(incidents).

    LOOP AT incidents INTO DATA(incident).

      IF incident-Title IS INITIAL
         OR incident-Description IS INITIAL
         OR incident-Priority IS INITIAL.

        APPEND VALUE #( %tky = incident-%tky ) TO failed-Incident.

        APPEND VALUE #(
          %tky = incident-%tky
          %msg = new_message(
          id       = 'ZMSG'
          number   = '001'
          severity = if_abap_behv_message=>severity-error
          v1       = 'Faltan campos obligatorios'
          )
        ) TO reported-Incident.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
