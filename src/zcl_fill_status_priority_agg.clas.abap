* Clase utilitaria para cargar los datos maestros de estados y prioridades.
* Se ejecuta como consola (if_oo_adt_classrun) directamente desde ADT con F9.
* Hay que ejecutarla una sola vez tras activar las tablas ZDT_STATUS_AGG y ZDT_PRIORITY_AGG.
CLASS zcl_fill_status_priority_agg DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_fill_status_priority_agg IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    " Limpiamos los datos existentes para evitar duplicados en cada ejecución
    DELETE FROM zdt_status_agg.
    DELETE FROM zdt_priority_agg.

    " Insertamos los 6 estados válidos del sistema
    INSERT zdt_status_agg FROM TABLE @( VALUE #(
      ( status_code = 'OP'  status_description = 'Open' )
      ( status_code = 'IP'  status_description = 'In Progress' )
      ( status_code = 'PE'  status_description = 'Pending' )
      ( status_code = 'CO'  status_description = 'Completed' )
      ( status_code = 'CL'  status_description = 'Closed' )
      ( status_code = 'CN'  status_description = 'Canceled' )
    ) ).
    IF sy-subrc = 0.
      out->write( |{ sy-dbcnt } Status records were added successfully| ).
    ENDIF.

    " Insertamos las 3 prioridades válidas del sistema
    INSERT zdt_priority_agg FROM TABLE @( VALUE #(
      ( priority_code = 'H'  priority_description = 'High' )
      ( priority_code = 'M'  priority_description = 'Medium' )
      ( priority_code = 'L'  priority_description = 'Low' )
    ) ).
    IF sy-subrc = 0.
      out->write( |{ sy-dbcnt } Priority records were added successfully| ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.

