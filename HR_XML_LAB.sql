-- ==========================================================================
-- LABORATORIO NO. 1 - Almacenamiento y validación de ficheros XML en Oracle
-- ==========================================================================

-- ========================================
-- Generación del XML
-- ========================================
SET SERVEROUTPUT ON SIZE UNLIMITED;

DECLARE
    v_xml CLOB;
BEGIN
    SELECT 
        XMLSERIALIZE(DOCUMENT
            XMLELEMENT("empleados",
                XMLAGG(
                    XMLELEMENT("empleado",
                        XMLATTRIBUTES(e.employee_id AS "id_empleado"),
                        XMLFOREST(
                            e.first_name AS "nombre",
                            e.last_name AS "apellido",
                            e.email AS "email",
                            e.phone_number AS "telefono",
                            TO_CHAR(e.hire_date, 'YYYY-MM-DD') AS "fecha_contratacion",
                            e.salary AS "salario"
                        ),
                        XMLELEMENT("departamento",
                            XMLATTRIBUTES(d.department_id AS "id_dept"),
                            XMLFOREST(
                                d.department_name AS "nombre_dept",
                                l.city AS "ubicacion"
                            )
                        )
                    )
                )
            )
        AS CLOB INDENT SIZE = 2)
    INTO v_xml
    FROM employees e
    JOIN departments d ON e.department_id = d.department_id
    JOIN locations l ON d.location_id = l.location_id
    WHERE e.salary > 5000
    AND ROWNUM <= 10;
    
    DBMS_OUTPUT.PUT_LINE(v_xml);
END;
/


-- ========================================
-- LIMPIAR TODO
-- ========================================
BEGIN
    EXECUTE IMMEDIATE 'DROP TRIGGER trg_validar_xml';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE empleados_xml PURGE';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    DBMS_XMLSCHEMA.deleteschema(
        schemaurl => 'http://localhost/empleados_departamentos.xsd',
        delete_option => DBMS_XMLSCHEMA.DELETE_CASCADE_FORCE
    );
EXCEPTION WHEN OTHERS THEN NULL;
END;
/


-- ========================================
-- REGISTRAR ESQUEMA
-- ========================================
BEGIN
    DBMS_XMLSCHEMA.registerschema(
        schemaurl => 'http://localhost/empleados_departamentos.xsd',
        schemadoc => '<?xml version="1.0" encoding="UTF-8"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <xs:element name="empleados">
    <xs:complexType>
      <xs:sequence>
        <xs:element name="empleado" maxOccurs="unbounded">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="nombre" type="xs:string"/>
              <xs:element name="apellido" type="xs:string"/>
              <xs:element name="email" type="xs:string"/>
              <xs:element name="telefono" type="xs:string" minOccurs="0"/>
              <xs:element name="fecha_contratacion" type="xs:date"/>
              <xs:element name="salario" type="xs:decimal"/>
              <xs:element name="departamento">
                <xs:complexType>
                  <xs:sequence>
                    <xs:element name="nombre_dept" type="xs:string"/>
                    <xs:element name="ubicacion" type="xs:string"/>
                  </xs:sequence>
                  <xs:attribute name="id_dept" type="xs:integer" use="required"/>
                </xs:complexType>
              </xs:element>
            </xs:sequence>
            <xs:attribute name="id_empleado" type="xs:integer" use="required"/>
          </xs:complexType>
        </xs:element>
      </xs:sequence>
    </xs:complexType>
  </xs:element>
</xs:schema>',
        local => TRUE,
        gentypes => FALSE,
        genbean => FALSE,
        gentables => FALSE
    );
END;
/

-- ========================================
-- CREAR TABLA
-- ========================================
CREATE TABLE empleados_xml (
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    xml_data XMLTYPE
) XMLTYPE COLUMN xml_data 
  XMLSCHEMA "http://localhost/empleados_departamentos.xsd" 
  ELEMENT "empleados";

-- ========================================
-- TRIGGER
-- ========================================
CREATE OR REPLACE TRIGGER trg_validar_xml
BEFORE INSERT OR UPDATE ON empleados_xml
FOR EACH ROW
DECLARE
    v_apellido VARCHAR2(100);
    v_salario NUMBER;
BEGIN
    -- Verificar apellido
    SELECT EXTRACTVALUE(:NEW.xml_data, '/empleados/empleado/apellido')
    INTO v_apellido
    FROM DUAL;
    
    IF v_apellido IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Error: Falta el elemento obligatorio "apellido"');
    END IF;
    
    -- Verificar salario (el error lo captura automáticamente Oracle)
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
/

-- ========================================
-- INSERCIÓN CORRECTA
-- ========================================
INSERT INTO empleados_xml (xml_data) VALUES (
    XMLTYPE('<empleados><empleado id_empleado="999"><nombre>Carlos</nombre><apellido>Rodriguez</apellido><email>CRODRIGUEZ</email><telefono>1.555.999.0001</telefono><fecha_contratacion>2024-01-15</fecha_contratacion><salario>15000</salario><departamento id_dept="60"><nombre_dept>IT</nombre_dept><ubicacion>Bogotá</ubicacion></departamento></empleado></empleados>')
);

COMMIT;

SELECT id, XMLSERIALIZE(CONTENT xml_data AS CLOB INDENT SIZE = 2) AS xml_formateado
FROM empleados_xml;


-- ========================================
-- INSERCIÓN INCORRECTA 1: SIN APELLIDO
-- ========================================
INSERT INTO empleados_xml (xml_data) VALUES (
    XMLTYPE('<empleados><empleado id_empleado="998"><nombre>Maria</nombre><email>MGARCIA</email><telefono>1.555.998.0001</telefono><fecha_contratacion>2024-02-20</fecha_contratacion><salario>12000</salario><departamento id_dept="50"><nombre_dept>Ventas</nombre_dept><ubicacion>Madrid</ubicacion></departamento></empleado></empleados>')
);


-- ========================================
-- INSERCIÓN INCORRECTA 2: SALARIO TEXTO
-- ========================================
INSERT INTO empleados_xml (xml_data) VALUES (
    XMLTYPE('<empleados><empleado id_empleado="997"><nombre>Juan</nombre><apellido>Pérez</apellido><email>JPEREZ</email><telefono>1.555.997.0001</telefono><fecha_contratacion>2024-03-10</fecha_contratacion><salario>MUCHO_DINERO</salario><departamento id_dept="80"><nombre_dept>Finanzas</nombre_dept><ubicacion>Lima</ubicacion></departamento></empleado></empleados>')
);














