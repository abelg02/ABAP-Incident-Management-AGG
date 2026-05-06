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
  ENDMETHOD.

  METHOD setHistory.
  ENDMETHOD.

  METHOD setDefaultValues.
  ENDMETHOD.

  METHOD setDefaultHistory.
  ENDMETHOD.

  METHOD validateDates.
  ENDMETHOD.

  METHOD validateDeleteStatus.
  ENDMETHOD.

  METHOD validateMandatoryFields.
  ENDMETHOD.

ENDCLASS.
