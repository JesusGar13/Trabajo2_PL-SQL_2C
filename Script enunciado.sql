drop table modelos            cascade constraints;
drop table vehiculos        cascade constraints;
drop table clientes         cascade constraints;
drop table facturas       cascade constraints;
drop table lineas_factura     cascade constraints;
drop table reservas      cascade constraints;

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

create or replace procedure alquilar_coche(arg_NIF_cliente varchar,
  arg_matricula varchar, arg_fecha_ini date, arg_fecha_fin date) is
-- declaraciones necesarias
begin
  null;
  -- implementa aquí tu procedimiento
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
	 
  --caso 1 nro dias negativo
  begin
    inicializa_test;
    -- Implementa aquí tu test
  end;
  
  --caso 2 vehiculo inexistente
  begin
    inicializa_test;
    -- Implementa aquí tu test
  end;
  
  --caso 3 cliente inexistente
  begin
    inicializa_test;
   -- Implementa aquí tu test
  end;
  

  --caso 4 Intentar alquilar un coche ya alquilado
  
  --4.1 la fecha ini del alquiler esta dentro de una reserva
  begin
    inicializa_test;    
	-- Implementa aquí tu test
  end; 
  
   --4.2 la fecha fin del alquiler esta dentro de una reserva
  begin
    inicializa_test;    
	-- Implementa aquí tu test
  end; 
  
  --4.3 el intervalo del alquiler esta dentro de una reserva
  begin
    inicializa_test;    
	-- Implementa aquí tu test
  end; 
  
   --caso 5 Todo correcto
  declare
                                                                          
  begin
    inicializa_test; 
    -- Implementa aquí tu test
  end;
 
end;
/

set serveroutput on
exec test_alquila_coches;
