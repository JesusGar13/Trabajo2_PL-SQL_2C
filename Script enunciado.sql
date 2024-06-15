drop table modelos cascade constraints;
drop table vehiculos cascade constraints;
drop table clientes cascade constraints;
drop table facturas cascade constraints;
drop table lineas_factura cascade constraints;
drop table reservas cascade constraints;

drop sequence seq_modelos;
drop sequence seq_num_fact;
drop sequence seq_reservas;

create table clientes(
  NIF varchar(9) primary key,
  nombre  varchar(20) not null,
  ape1  varchar(20) not null,
  ape2  varchar(20) not null,
  direccion varchar(40) 
);


create sequence seq_modelos;

create table modelos(
  id_modelo     integer primary key,
  nombre      varchar(30) not null,
  precio_cada_dia   numeric(6,2) not null check (precio_cada_dia>=0));


create table vehiculos(
  matricula varchar(8)  primary key,
  id_modelo integer  not null references modelos,
  color   varchar(10)
);

create sequence seq_reservas;
create table reservas(
  idReserva integer primary key,
  cliente   varchar(9) references clientes,
  matricula varchar(8) references vehiculos,
  fecha_ini date not null,
  fecha_fin date,
  check (fecha_fin >= fecha_ini)
);

create sequence seq_num_fact;
create table facturas(
  nroFactura  integer primary key,
  importe   numeric( 8, 2),
  cliente   varchar(9) not null references clientes
);

create table lineas_factura(
  nroFactura  integer references facturas,
  concepto  char(40),
  importe   numeric( 7, 2),
  primary key ( nroFactura, concepto)
);

create or replace procedure alquilar_coche(arg_NIF_cliente varchar, arg_matricula varchar, arg_fecha_ini date, arg_fecha_fin date) is
  v_id_modelo integer;
  v_precio_diario numeric(6,2);
  v_dias_alquiler integer;
  v_cliente_exist integer;
  v_factura_id integer;
begin
  -- Comprobamos las fechas
  if arg_fecha_ini > arg_fecha_fin then
    raise_application_error(-20001, 'No pueden realizarse alquileres por periodos inferiores a 1 día');
  end if;

  -- Consultamos el modelo y el precio diario del vehiculo
  begin 
    select v.id_modelo, m.precio_cada_dia
    into v_id_modelo, v_precio_diario
    from vehiculos v join modelos m on v.id_modelo = m.id_modelo
    where v.matricula = arg_matricula
    for update;

    exception   -- Si no encuentra el modelo, no existe el vehiculo con la matricula 
      when no_data_found then 
        raise_application_error(-20002, 'Vehículo inexistente.');
  end;


  -- Comprobamos que este disponible las fechas
  begin
    select count(*)
    into v_cliente_exist
    from reservas r
    where r.matricula = arg_matricula
      and ((arg_fecha_ini between r.fecha_ini and r.fecha_fin) 
        or (arg_fecha_fin between r.fecha_ini and r.fecha_fin) 
        or (arg_fecha_ini <= r.fecha_ini and arg_fecha_fin >= r.fecha_fin))
    for update;
  exception
    when others then  -- excepcion para tratar un fallo en la consulta
      raise_application_error(-20003, 'Error al comprobar la disponibilidad del vehículo.');
  end;

  if v_cliente_exist > 0 then -- Comprobamos que no hay clientes entre las fechas ini y fin
    raise_application_error(-20003, 'El vehículo no está disponible para esas fechas.');
  end if;
  

  -- Consultamos el numero de clientes con ese NIF, solo debe haber 1
  select count(*)
  into v_cliente_exist
  from clientes c
  where c.NIF = arg_NIF_cliente;

  if v_cliente_exist = 0 then -- Si no hay cliente con ese NIF, no existe
    raise_application_error(-20004, 'Cliente inexistente');
  end if;

  -- Insetamos la fila de la reserva
  insert into reservas (idReserva, cliente, matricula, fecha_ini, fecha_fin)
  values (seq_reservas.nextval, arg_NIF_cliente, arg_matricula, arg_fecha_ini, arg_fecha_fin);

  -- Insertamos la fila de la factura
  insert into facturas (nroFactura, importe, cliente)
  values (seq_num_fact.nextval, v_precio_diario * (arg_fecha_fin - arg_fecha_ini), arg_NIF_cliente)
  returning nroFactura into v_factura_id;

  -- Insertamos la linea de la factura insertada, mismo nroFactura
  insert into lineas_factura (nroFactura, concepto, importe)
  values (v_factura_id, (arg_fecha_fin - arg_fecha_ini) || ' días de alquiler vehículo modelo ' || v_id_modelo, v_precio_diario * (arg_fecha_fin - arg_fecha_ini));

  commit;

end;
/

create or replace
procedure reset_seq( p_seq_name varchar )
--From https://stackoverflow.com/questions/51470/how-do-i-reset-a-sequence-in-oracle
is
    l_val number;
begin
    --Averiguo cual es el siguiente valor y lo guardo en l_val
    execute immediate
    'select ' || p_seq_name || '.nextval from dual' INTO l_val;

    --Utilizo ese valor en negativo para poner la secuencia cero, pimero cambiando el incremento de la secuencia
    execute immediate
    'alter sequence ' || p_seq_name || ' increment by -' || l_val || 
                                                          ' minvalue 0';
   --segundo pidiendo el siguiente valor
    execute immediate
    'select ' || p_seq_name || '.nextval from dual' INTO l_val;

    --restauro el incremento de la secuencia a 1
    execute immediate
    'alter sequence ' || p_seq_name || ' increment by 1 minvalue 0';

end;
/

create or replace procedure inicializa_test is
begin
  reset_seq( 'seq_modelos' );
  reset_seq( 'seq_num_fact' );
  reset_seq( 'seq_reservas' );
        
  
    delete from lineas_factura;
    delete from facturas;
    delete from reservas;
    delete from vehiculos;
    delete from modelos;
    delete from clientes;
   
    
    insert into clientes values ('12345678A', 'Pepe', 'Perez', 'Porras', 'C/Perezoso n1');
    insert into clientes values ('11111111B', 'Beatriz', 'Barbosa', 'Bernardez', 'C/Barriocanal n1');
    
    
    insert into modelos values ( seq_modelos.nextval, 'Renault Clio Gasolina', 15);
    insert into vehiculos values ( '1234-ABC', seq_modelos.currval, 'VERDE');

    insert into modelos values ( seq_modelos.nextval, 'Renault Clio Gasoil', 16);
    insert into vehiculos values ( '1111-ABC', seq_modelos.currval, 'VERDE');
    insert into vehiculos values ( '2222-ABC', seq_modelos.currval, 'GRIS');
  
    commit;
end;
/


exec inicializa_test;



create or replace procedure test_alquila_coches is
begin
  -- Caso 1: Todo correcto
  begin
    inicializa_test;
    alquilar_coche('12345678A', '1234-ABC', date '2024-06-15', date '2024-06-18');
    dbms_output.put_line('Caso 1 - Reserva exitosa.');
  end;

  -- Caso 2: Número de días negativo
  begin
    inicializa_test;
    begin
      alquilar_coche('12345678A', '1234-ABC', date '2024-06-15', date '2024-06-14');
    exception
      when others then
        dbms_output.put_line('Caso 2 - Error: ' || sqlerrm);
    end;
  end;

  -- Caso 3: Vehículo inexistente
  begin
    inicializa_test;
    begin
      alquilar_coche('12345678A', '9999-XYZ', date '2024-06-15', date '2024-06-18');
    exception
      when others then
        dbms_output.put_line('Caso 3 - Error: ' || sqlerrm);
    end;
  end;

  -- Caso 4: Intentar alquilar un coche ya alquilado
  -- 4.1 La fecha ini del alquiler está dentro de una reserva
  begin
    inicializa_test;
    alquilar_coche('12345678A', '1234-ABC', date '2024-06-15', date '2024-06-20');

    begin
      alquilar_coche('11111111B', '1234-ABC', date '2024-06-18', date '2024-06-24');
    exception
      when others then
        dbms_output.put_line('Caso 4.1 - Error: ' || sqlerrm);
    end;
  end;

  -- 4.2 La fecha fin del alquiler está dentro de una reserva
  begin
    inicializa_test;
    alquilar_coche('12345678A', '1234-ABC', date '2024-06-15', date '2024-06-20');

    begin
      alquilar_coche('11111111B', '1234-ABC', date '2024-06-12', date '2024-06-16');
    exception
      when others then
        dbms_output.put_line('Caso 4.2 - Error: ' || sqlerrm);
    end;
  end;

  -- 4.3 El intervalo del alquiler está dentro de una reserva
  begin
    inicializa_test;
    alquilar_coche('12345678A', '1234-ABC', date '2024-06-15', date '2024-06-20');

    begin
      alquilar_coche('11111111B', '1234-ABC', date '2024-06-16', date '2024-06-18');
    exception
      when others then
        dbms_output.put_line('Caso 4.3 - Error: ' || sqlerrm);
    end;
  end;

  -- Caso 5: Cliente inexistente
  begin
    inicializa_test;
    begin
      alquilar_coche('99999999Z', '1234-ABC', date '2024-06-15', date '2024-06-18');
    exception
      when others then
        dbms_output.put_line('Caso 5 - Error: ' || sqlerrm);
    end;
  end;

end;
/


set serveroutput on
exec test_alquila_coches;

/*
P5a - ¿Por qué crees que se hace la recomendación del paso 2? 
      Con el join entre las tablas de vehiculos y modelos obtenemos todos los vehiculos posibles de nuestra BD
      Si al obtener el precioDia y el modelo del vehiculo con la matricula pasada por argumento no encuentra estos datos 
      significa que el vehiculo con esa matricula no existe.(Matamos dos pajaros de un tiro)

P5b - El resultado de la SELECT del paso 4, ¿sigue siendo fiable en el paso 5?, ¿por qué? 
      Sigue siendo fiable, si el cliente existe para crear una reserva, tambien existira para realizar la insercion 
      en la tabla facturas de dicho cliente.

P5c - En este paso, la ejecución concurrente del mismo procedimiento ALQUILA con, quizás otros o los 
mismos argumentos, ¿podría habernos añadido una reserva no recogida en esa SELECT que fuese 
incompatible con nuestra reserva?, ¿por qué?. 
      En el caso de que dos transaciones concurrentes que intenten alquilar, la select que comprueba la disponibilidad del 
      vehiculo puede causar errores ya que una transaccion podria verificar la disponibilidad del vehiculo, 
      luego otra reservar ese vehiculo y que la primera reserve el mismo vehiculo que la sefgunda.
      Para solucionar este problema podemos bloquear las filas que esta consultando con ayuda de FOR UPDATE.

P5d - ¿Qué tipo de estrategia de programación has empleado en tu código? ¿Cómo se refleja esto en tu 
código? (la respuesta a esta segunda pregunta del apartado d es necesaria para poder evaluar la 
primera) 
      No se ha usado una única estrategia, se ha programado tanto de forma defensiva, con comprobación y verificación de datos
      para verificar las fechas o la existencia del cliente, como con el control de excepciones como ha sido con la 
      comprobacion de existia el vehiculo con la consulta del modelo y precioDia.
*/
