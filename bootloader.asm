BUFFER_SIZE equ 128 ;Tamaño maximo del buffer de comandos
IDT_OFFSET equ 9*4  ;Interrupcion de la irq de teclado

BITS 16

ORG 7c00h ; Direccion donde se guarda el codigo

CLI ; Ignora interrupciones

MOV AX, 0x3
INT 10h; Activo el modo texto para la pantalla.

MOV DH, 0x0 ; Cabecera disco
MOV DL, 0x0 ; Disco
MOV CH, 0x0 ; Cilindro
MOV CL, 0x02 ; Sector (Segundo, el primero ES el bootloader)

DISK_LOAD:
MOV AH, 0x02 ; Leer sectores
MOV AL, 0x04 ; Numero de sectores a leer
MOV BX, SECOND_STAGE ; BX se inicia con la direccion de second stage [ES:BX] buffer disco
INT 0x13 ; Interrupcion 13 del disco

JC DISK_LOAD ; Si hay error se reintenta, Flag 1

JMP AQUI;Salta a la direccion de la segunda etapa cargada

times 510 - ($ - $$) db 0 ;Se rellena el resto con 0

dw 0xaa55 ; magic number para definir el bootloader


SECOND_STAGE:  ;Etiqueta donde comienza la second stage

MSG: db "root@system$ ",0 ;Mensaje de la terminal
DECLARED_COMAND1: db "time",0; Comando para obtener la hora actual
DECLARED_COMAND2: db "clear",0; Comando para limpiar pantalla
DECLARED_COMAND3: db "pm",0; Comando para pasar a modo protegido
                 
TWO_POINTS: db ":",0
TIME_MSG: db "La hora actual es: ",0

PINTAR_SYS:;Funcion para pintar el mensaje de la terminal
    MOV AH,0x0F;Color de fondo y letra
    MOV SI,MSG;Se almacena el mensaje en SI
    LOOP_SYS:
    LODSB;Se pasa de SI a AL y se incrementa SI
    OR AL,AL;Si AL ES 0 sale
    JZ EXIT
    STOSW; Se mueve AL a [ES:DI] que esta la direccion de memoria de video y se incrementa
    JMP LOOP_SYS


EXIT:;Vuelve a donde le hayan llamado
    RET

;Se llama AL borrar caracteres, pulsando la tecla de retroceso
DELETE:
    MOV CX,[CS:BUFFER_WRITE_POS]
    CMP CX,0;Si DI ES igual a esa direccion (Direccion de video)
    JE EXIT_DELETE; No puede borrar mas(sino borra el sys de la linea actual)
    STD;Se cambia a decrementar la memoria AL realizar Stosw
    MOV AH,0x0F
    MOV AL,0
    STOSW;Retrocede dos posiciones y las pinta a cero(cursor actual que no hay nada y la que se quiere borrar)
    STOSW
    CLD;Se cambia a incrementar
    MOV AL, ES:DI;Se almacena en la actual, el mismo caracter escrito y avanza una, asi esta en el caracter borrado
    STOSW

    CALL MOVE_CURSOR;Se mueve el cursor a la posicion actual

    MOV CX,[CS:BUFFER_WRITE_POS];Se almacena en CX la posicion del cursor de escritura en el buffer de comandos
    MOV SI,CX;Se almacena en SI
    LEA CX,[SI-1];Se almacena en CX, la direccion de la direccion de SI-1 que ES el valor de SI-1
    MOV [CS:BUFFER_WRITE_POS],CX;Se almacena en la posicion el nuevo valor
    EXIT_DELETE:;Se salta aqui si no se puede borrar mas

    JMP RETURN;Se regresa a la ISR

;Cargan en SI los comandos declarados antes
LOAD_COMMAND1:
    MOV SI,DECLARED_COMAND1
    RET
LOAD_COMMAND2:
    MOV SI,DECLARED_COMAND2  
    RET
LOAD_COMMAND3:
    MOV SI,DECLARED_COMAND3
    RET    

;Se carga el comando actual segun el registro AX que ES un contador para comparar el comando actual
LOAD_CURRENT:
    CMP AX,3;Si ES 3 carga el primero y asi
    JE LOAD_COMMAND1

    CMP AX,2
    JE LOAD_COMMAND2

    CMP AX,1
    JE LOAD_COMMAND3

    RET

;Se ha pulsado la tecla enter por lo que se compara el comando del buffer con los programados
COMAND:
    ;1º Se iteran por los comandos
    MOV AX,3;Numero de comandos
    LOOP_COMAND:
    CALL LOAD_CURRENT;Carga en SI el comando actual segun AX
    PUSH AX;Se almacena AX sin reducir
    CALL LONGITUD_COMANDO;Con SI, devuelve CX con la longitud

    PUSH CX;Se almacena la longitud

    ;2º Carga el puntero den escritura y compara valores
    MOV DX,[CS:BUFFER_WRITE_POS];Se carga en DX la posicion del cursor de escritura
    CMP CX,DX
    JNE NOT_EQUAL;Si no ES igual pasa AL siguiente comando o sale SI no hay mas

    ;3º Si ES de igual longitud que el actual se comparan los caracteres de ambos comandos
    MOV DX,0;Es contador de SI para recorrer el buffer
    MOV SI,DX
    MOV CX,[CS:KEYBOARD_BUFFER+SI];Se obtiene la posicion del buffer 

    POP DX;Se obtiene la longitud
    POP AX;Se obtiene el contador de comando
    CALL LOAD_CURRENT;Se carga de nuevo en SI el actual comando
    PUSH AX;Se almacena lo de antes 
    PUSH DX
    MOV DX,0;Se restablece DX a cero antes del bucle

    ;Se comparan los caracteres del comando programado con los del buffer
    LOOP_COMPARE:
        LODSB
        OR AL,AL
        JZ NOT_EQUAL;Si el comando no tiene mas caracteres sale
        CMP AL,CL;Si tiene se comapara los caracteres
        JNE NOT_EQUAL;No ES igual sale(no son iguales)

        INC DX;Si los son se aumenta el contador de caracter del buffer
        PUSH SI;Se almacena SI, valor de comando programado
        MOV SI,DX;Se pasa DX y se obtiene el valor
        MOV CX,[CS:KEYBOARD_BUFFER+SI]
        POP SI;Se restablece SI

    JMP LOOP_COMPARE

    NOT_EQUAL:
    ;Obtiene el contador de comando y la longitud almacenados
    POP CX
    POP AX
    CMP DX,CX;Si el contador ES igual AL tamaño(todos caracteres iguales) salta
    JE CHECK_COMAND

    
    SUB AX,1;se resta 1 AL contador de comando si no ES igual
    ;Si ES 0 vuelve no coincide ninguno vuelve
    CMP AX,0
    JE RETURN

    

    JMP LOOP_COMAND

;Si el comando ES igual segun el valor del contador de comando salta a una funcionalidad
CHECK_COMAND:
    CMP AX,3
    JE TIME
    CMP AX,2
    JE CLEAR
    CMP AX,1
    JE PROTECTED_MODE
    
    
;Modo protegido
PROTECTED_MODE:

    CALL CLEAR_PM;Limpia buffer, cursor ES reseteado y la pantalla se borra
    MOV AX,0;Se cambia la direccion de memoria de video del registro
    MOV ES,AX
    MOV DI,AX

    CALL MOVE_CURSOR

    JMP RETURN;Vuelve
    

;Se limpia todo para pasar a modo protegido
CLEAR_PM:
    STD;Se recorre la pantalla y se borra todo
    MOV AH,0x0F
    MOV AL,0
    LOOP_CLEAR_PM:
    CMP DI,0
    JE RESET_PM
    STOSW
    JMP LOOP_CLEAR_PM
;Se resetea el indice de incremento o decremento de stosw y limpia buffer
RESET_PM:
    CLD
    CALL CLEAR_BUFFER
    RET   

;Se llama AL ejecutar comando de limpiar pantalla
CLEAR:
    STD
    MOV AH,0x0F
    MOV AL,0
    LOOP_CLEAR:
    CMP DI,0
    JE RESET
    STOSW
    JMP LOOP_CLEAR
    
;Se llama despues de limpiar la pantalla
RESET:
    CLD;restablece incremento de stosw
    CALL PINTAR_SYS;Se pinta el sistema
    CALL CLEAR_BUFFER;se limpia el buffer
    CALL MOVE_CURSOR;Se restablece el cursor
    JMP RETURN;vuelve

;Se llama AL ejecutar el comando de la hora
TIME:
    CALL CALCULATE_ROW;Se calcula la fila actual
    CALL NEWLINE;Se realiza un salto de linea

    MOV SI,TIME_MSG;Se pinta por pantalla el mensaje de la hora antes de pintar la hora
    LOOP_PRINT_MSG:
    LODSB
    OR AL,AL
    JZ HORA
    MOV AH,0X0F
    STOSW
    JMP LOOP_PRINT_MSG

    ;Se obtiene la hora
    HORA:
    MOV DX,0x70
    MOV AL,0x04
    OUT DX,AL

    MOV DX,0x71
    IN AL,DX;Registro HORAS
    MOV AH,0
    CALL BCD_CONVERT;Se convierte a decimal
    MOV AH,0
    CALL SEPARATE_NUMBER;Se separa en numeros sueltos
    MOV AL,[BUFFER_TIME];Se obtiene el primer numero del buffer (son dos ya que la hora solo tiene dos valores maximo)
    MOV AH,0X0F
    ADD AL,48;Se pinta el valor sumandole 48 que ES el 0 en codigo 437 ya que sino pinta el numero que corresponda con esa tabla
    STOSW
    MOV AL,[BUFFER_TIME+1];Se realiza lo mismo con el segundo valor
    MOV AH,0X0F
    ADD AL,48
    STOSW

    MOV SI,TWO_POINTS;Se pintan los dos puntos
    LOOP_PRINT_MSG1:
    LODSB
    OR AL,AL
    JZ SIG
    MOV AH,0X0F
    STOSW
    JMP LOOP_PRINT_MSG1

    SIG:
    MOV DX,0x70;Se realiza de nuevo con los minutos
    MOV AL,0x02
    OUT DX,AL

    MOV DX,0x71
    IN AL,DX;Registro MINUTOS
    MOV AH,0
    CALL BCD_CONVERT
    MOV AH,0
    CALL SEPARATE_NUMBER
    MOV AL,[BUFFER_TIME]
    MOV AH,0X0F
    ADD AL,48
    STOSW
    MOV AL,[BUFFER_TIME+1]
    MOV AH,0X0F
    ADD AL,48
    STOSW

    
    MOV SI,TWO_POINTS;Se pintan dos puntos
    LOOP_PRINT_MSG2:
    LODSB
    OR AL,AL
    JZ SIG2
    MOV AH,0X0F
    STOSW
    JMP LOOP_PRINT_MSG2

    SIG2:
    MOV DX,0x70;Se repite con los segundos
    MOV AL,0x00
    OUT DX,AL

    MOV DX,0x71
    IN AL,DX;Registro SEGUNDOS
    MOV AH,0
    CALL BCD_CONVERT
    MOV AH,0
    CALL SEPARATE_NUMBER
    MOV AL,[BUFFER_TIME]
    MOV AH,0X0F
    ADD AL,48
    STOSW
    MOV AL,[BUFFER_TIME+1]
    MOV AH,0X0F
    ADD AL,48
    STOSW
  
    JMP CREATE_NEWLINE;Se añade una nueva linea

;Convierte de BCD a decimal
BCD_CONVERT:
    ;AL DATO Y DEVUELVE
    MOV CL,AL;Se almacena en CL y DL al
    MOV DL,AL

    AND AL,0xF0;Se aplica una mascara para obtener los bits mas significativos 
    SHR AL,1;Se desplaza un bit hacia abajo

    AND CL,0xF0;Se aplica la misma a CL
    SHR CL,3;Se desplaza 3 bits

    AND DL,0xf;Se repite con DL

    ADD AL,CL;Se suma todo en AL y se obtiene el numero decimal
    ADD AL,DL
    RET

;Para pintar por separado cada numero,Sino pinta lo que este en esa posicion de la tabla
SEPARATE_NUMBER:
    LEA SI,[BUFFER_TIME+1];Se inicia el buffer al ultimo valor
    
    LOOP_TIME:;Mientras el cociente no sea cero
    XOR DX,DX
    PUSH AX
    PUSH BX
    MOV BX,10;Se obtiene resto de AX: Dividendo con el numero y BX: Divisor con 10
    CALL RESTO
    ;DX tiene resto
    MOV [SI],DL;Se almacena en el buffer
    POP BX
    POP AX;Se obtiene el numero de nuevo
    PUSH BX
    
    MOV BX,10
    CALL DIVIDIR;Se divide para obtener el cociente
    POP BX
    MOV AX,CX;CX tiene el cociente y se pasa a AX como dividendo

    DEC SI;Se decrementa SI
    TEST AX,AX
    JZ EXIT_SEPARATE;Si ES cero se sale
    JMP LOOP_TIME
EXIT_SEPARATE:    
    RET

;Para pintar una nueva linea
CREATE_NEWLINE:
    CALL CLEAR_BUFFER;Se limpia el buffer
    CALL CALCULATE_ROW;Se calcula la fila
    CALL NEWLINE;Se salta a la nueva linea
    CALL PINTAR_SYS;Se pinta el sistema
    CALL MOVE_CURSOR;Se mueve el cursor
    JMP RETURN

;Obtiene la longitud del comando programado
LONGITUD_COMANDO:
    MOV CX,0;CX ES el contador
    CONT:;Se itera por los caracteres y se aumenta el contador
    LODSB
    OR AL,AL
    JZ SALIR_CONTADOR
    INC CX
    JMP CONT
    SALIR_CONTADOR:
    RET   

;Calcula la fila con la posicion de memoria de video
CALCULATE_ROW:
    MOV CX,DI;Se obtiene DI que ES los bits bajos de la memoria de video
    MOV AX,CX;Se almacena en AX
    PUSH BX;Se guarda BX(tabla ascii)
    MOV BX,160;Se almacena 160 caracteres por linea (80 * 2 bytes(color de texto y fondo))
    CALL DIVIDIR;Se divide para obtener el numero de lineas y ese ES la actual 
    ;CX TIENE VALOR
    POP BX;Restablece BX
    RET

;Calcula la columna
CALCULATE_COLUMN:
    MOV CX,DI;Se realiza el mismo proceso que con la fila
    MOV AX,CX
    PUSH BX
    MOV BX,160
    CALL RESTO;Se calcula el resto de la direccion entre 160(son las columnas ocupadas)
    ;dx RESTO
    MOV AX,DX;Se divide entre dos ya que cada columna ocupada son 2 bytes y se obtiene la columna real
    MOV BX,2
    CALL DIVIDIR
    POP BX
    ;CX TIENE LA COLUMNA
    RET

;Permite mover el cursor    
MOVE_CURSOR:
    CALL CALCULATE_ROW;Calcula la fila
    ;CX TIENE LA FILA
    PUSH CX;Almacena la fila
    CALL CALCULATE_COLUMN;Calcula la columna
    ;CX TIENE LA COLUMNA
    POP DX;Se obtiene la fila
    PUSH BX
    MOV BX,DX
    ;Se almacena en AH, el identificador para la interrupcion
    MOV AH,0x02
    MOV DH,BL;En DH, las filas
    MOV DL,CL;En DL,las columnas
    MOV BX,0x0;BX ES la pagina

    INT 10h;Se llama a la interrupcion 10h
    POP BX;Se restablece BX

    RET
;Pinta un salto de linea
NEWLINE:
    ;CX TIENE LA FILA antes de llamar
    ADD CX,1;Se incrementa en uno la fila
    MOV AX,160;Se multiplica la nueva fila por 160 para obtener la memoria
    PUSH BX
    MOV BX,CX
    CALL MULTIPLICAR
    POP BX
    ;AX TIENE LA POSICION
    MOV DI,AX;Se mueve a DI (ES:DI memoria de video)
    RET

;Limpia el buffer de escritura
CLEAR_BUFFER:
    MOV CX,0;Se asigna al cursor de escritura al inicio del buffer
    MOV [CS:BUFFER_WRITE_POS],CX
    RET

;Permite dividir dos numeros
DIVIDIR:
    ;AX Dividendo
    ;BX Divisor
    ;CX Cociente
    MOV CX,0
    MOV DX,AX
    LOOP_DIVIDIR:;Resta hasta obtener un numero menor que el divisor
        SUB AX,BX
        CMP AX, 0
        JL FINISH_DIVIDIR
        ADD CX,1
        JMP LOOP_DIVIDIR
    FINISH_DIVIDIR:
        RET

;Multiplica dos numeros
MULTIPLICAR:
    ;AX P1
    ;BX p2
    ;AX ES la solucion
    CMP AX,0;Si AX ES 0 sale y devuleve el 0
    JE SALIR_MULTIPLICAR
    CMP BX,0;Si no ES 0 pero BX si
    JE SALIR_MULTIPLICAR0;Asigna a AX 0 y sale
    MOV CX,AX ;Se copia AX en CX
    LOOP_MULTIPLICAR:
        ADD AX,CX;Se suma BX veces CX a AX
        SUB BX,1;Se reduce en 1 BX
        CMP BX,1;Si BX ES 1 sale
        JE SALIR_MULTIPLICAR
    JMP LOOP_MULTIPLICAR
    SALIR_MULTIPLICAR:
        RET
    SALIR_MULTIPLICAR0:
        MOV AX,0
        RET
;Resto de division de dos numeros
RESTO:
    ;AX Dividendo
    ;BX Divisor
    ;DEVUELVE DX RESTO
    MOV CX,0
    MOV DX,AX
    LOOP_RESTO:
        SUB AX,BX
        CMP AX, 0
        JL FINISH_RESTO
        ADD CX,1
        JMP LOOP_RESTO
    FINISH_RESTO:;Una vez con CX como cociente, Dividendo(DX) - (Divisor(BX) * Cociente(CX)) = resto 
        MOV AX,CX
        CALL MULTIPLICAR
        SUB DX,AX
        RET

;Comienza el codigo principal de la Second stage
AQUI:

    MOV AX,0x0;Se mueve a DS, 0 para acceder al segmento 0x00 (donde esta la tabla de interrupciones)
    MOV DS, AX
    CLI ;Se desactivan las interrupciones
    MOV word [IDT_OFFSET], ISR;Se cambia en el segmento 0x00:IDT_OFFSET(numero 9 en la tabla * 4 de desplazamiento) = 36 en hexadecimal 0x24
    MOV [IDT_OFFSET+2], AX;Se modifica el segmento de la interrupcion en 0x26
    STI;Se activan las interrupciones

    
    MOV AX, 0xb800;Se mueve a ES, la direccion de video de VGA
    MOV ES, AX
    XOR DI, DI;Se anula DI para que sea 0
    MOV AH, 0x0F;Se mueve a AH el color de texto y fondo
    MOV BX, KEYBOARD_MAP;Se mueve a BX, el mapa del teclado para poder convertir con XLAT
    CLD;Se cambia a incrementar cada vez que se realiza un STOSW
    CALL PINTAR_SYS;Se pinta el sistema 
    CALL MOVE_CURSOR;Se mueve el cursor

;Bucle principal,devuelve el control al sistema hasta que haya una interrupcion
MAIN_LOOP:
    HLT
    MOV AX,0xB800;Si ES ha cambiado de valor, se va a pasar a modo protegido
    MOV CX,ES 
    CMP CX,AX
    JNE JUMP_PROTECTED_MODE;Se salta a modo protegido
    JMP MAIN_LOOP;Sino devuelve el control al sistema

;Salta a modo protegido
JUMP_PROTECTED_MODE:
    CLI;Desactiva interrupciones

    MOV AX,0x2401; Permite activar la linea A20
    INT 15h ;Envia interrupcion 15 para servicios extendidos del PC

    lgdt[GDT_descriptor] ; Activa la GDT creada

    MOV EAX, CR0 ; Se obtiene el valor de registro de CR0 para control de sistema y se almacena en EAX (Son 32 bits) y por eso se usa el extendido
    OR EAX, 0x1; Se realiza un OR para cambiar el ultimo bit (registro de paginacion)
    MOV CR0,EAX; Se cmabia el valor de CR0

    MOV AX, DATA_SEG ; Inicio de los registros con el segmento de datos
    MOV DS, AX
    MOV ES, AX
    MOV FS, AX
    MOV GS, AX
    MOV SS, AX

    JMP CODE_SEG:INI_PROTECTED_MODE; Se salta a la zona de segmento del GDT:PROTECT_MODE, DONDE INICIA ESTE

;ISR que se instanciará para el teclado
ISR:
    PUSH AX;Se guardan los registros 
    PUSH SI
    PUSH CX
    PUSH DX

    IN AL, 0x60;Se obtiene la interrupcion
    TEST AL, 0x80;Se comprueba si es igual a 0x80, si es una interrupcion de tecla pulsada
    JNE END ;Se modifica el flag ZF, si son iguales el flag es 1, estonces si es 0 salta e ignora la interrupcion
    
    XLAT;Se cambia el valor de AL por el valor de BX de la tabla usando AL como indice en la tabla
    TEST AL, AL;Si el valor no es valido sale
    JE END
    MOV DL,AL;Se mueve AL a DL
    CMP AL, 0X08;Se compara si el valor convertido es la tecla de retroceso, si es igual salta
    JE DELETE
    CMP AL, 0x0a;Se comprueba si el valor es la tecla enter, si lo es salta
    JE COMAND

    MOV AH,0x0f;Si no son estas teclas y es valido, se mueve a AH, el codigo de color
    MOV AL,DL;Se mueve a AL, el valor
    MOV CX, [CS:BUFFER_WRITE_POS];Se obtiene la posicion de buffer de escritura
    MOV SI, CX;Se obtiene la direccion
    cmp CX, BUFFER_SIZE-1;Si la posicion es la ultima del buffer, esta lleno y no se puede escribir
    JE END;Se sale si esta lleno

    LEA CX, [SI+1];Se almacena en CX el valor de la posicion +1
    MOV [CS:KEYBOARD_BUFFER+SI], AL; Se almacena en la nueva posicion el valor
    MOV [CS:BUFFER_WRITE_POS], CX; Se actualiza el cursor

    STOSW;Se pinta pasando AL a ES:DI y se incrementa DI

    CALL MOVE_CURSOR;Se mueve el cursor

    RETURN:;Vuelve de la tecla enter o return      

;Al salir
END:
    MOV AL, 0x20
    OUT 0x20, AL;Se envia al PIC que se ha leido la interrupcion

    ;Se restablecen los registros
    POP DX
    POP CX
    POP SI
    POP AX
    IRET;Se regresa de la interrupcion  

;Se alinea los buffer 2 bytes mas abajo del codigo
align 2
BUFFER_WRITE_POS: dw 0;posicion del cursor del buffer
KEYBOARD_BUFFER:    times BUFFER_SIZE db 0;Buffer de escritura
BUFFER_TIME: times 2 db 0;Buffer de hora para pintar la hora actual 

;Convertir de Scancode a ASCII
KEYBOARD_MAP:
    db  0,  27, '1', '2', '3', '4', '5', '6', '7', '8'    ; 9
    db '9', '0', '-', '=', 0x08                           ; Backspace
    db 0x09                                               ; Tab
    db 'q', 'w', 'e', 'r'                                 ; 19
    db 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 0x0a       ; Enter key
    db 0                                                  ; 29   - Control
    db 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';'   ; 39
    db "'", '`', 0                                        ; Left shift
    db "\", 'z', 'x', 'c', 'v', 'b', 'n'                  ; 49
    db 'm', ',', '.', '/', 0                              ; Right shift
    db '*'
    db 0                                                  ; Alt
    db ' '                                                ; Space bar
    db 0                                                  ; Caps lock
    db 0                                                  ; 59 - F1 key ... >
    db 0,   0,   0,   0,   0,   0,   0,   0
    db 0                                                  ; < ... F10
    db 0                                                  ; 69 - Num lock
    db 0                                                  ; Scroll Lock
    db 0                                                  ; Home key
    db 0                                                  ; Up Arrow
    db 0                                                  ; Page Up
    db '-'
    db 0                                                  ; Left Arrow
    db 0
    db 0                                                  ; Right Arrow
    db '+'
    db 0                                                  ; 79 - End key
    db 0                                                  ; Down Arrow
    db 0                                                  ; Page Down
    db 0                                                  ; Insert Key
    db 0                                                  ; Delete Key
    db 0,   0,   0
    db 0                                                  ; F11 Key
    db 0                                                  ; F12 Key
    times 128 - ($-KEYBOARD_MAP) db 0                     ; All other keys are undefined        


PROT_MODE:;Etiqueta de que comienza la second stage

;Definicion del GDT
GDT_Start:
    null_descriptor:; Se inicaliza el null descrptor a 0 (No usa la primera entrada)
        dd 0x0 ; 8 ceros (double words 4 bytes)
        dd 0x0 ; Otros 8 mas 16 bytes
    code_descriptor: ;Se crea el code descriptor 32 bits (Base 0 y limite 0xfffff 20 bits)
    ;Otros son Present 1 para segmentos, privilegios (00,01,..) y tipo (1 code, 0 dat seg)
    ;Flags: type flags -> code(1), confroming (ejecutado bajos privilegios (0)) ,Readble(0 solo y 1 tambien ejecutable), Accessed (usando el segmento (0))
    ;Other flags -> Granularidad(1), 32 bits (1), 64 bits (0),AVL (0)
        dw 0xffff ; 16 bits limite
        dw 0x0 ; 2 bytes (16 bits)
        db 0x0 ; 1 byte  (8 bits) = 24 
        db 10011010b ; Present,priv,type(1001) typeflags(1010) 
        db 11001111b ; Other flags(1100) + limit (ultimos 4 bits)
        db 0x0 ; 8 bits ultimos de la base
    data_descriptor: ; Para el data descriptor igual
        dw 0xffff
        dw 0x0
        db 0x0
        db 10010010b; Se cambia el bit de type flags de codigo a 0 porque no lo ES
        db 11001111b
        db 0x0 
GDT_End:

;Definir el descriptor
GDT_descriptor:
    dw GDT_End - GDT_Start - 1 ;Tamaño del descriptor
    dd GDT_Start ;Comienzo del descriptor

CODE_SEG equ code_descriptor - GDT_Start ;Se asigna a la constante el code 
DATA_SEG equ data_descriptor - GDT_Start ;Se asigna el data

BITS 32 ;Se activa los 32 BITS

Hola: 
    db "Bienvenido al MODO PROTEGIDO",0xD,0

;Salta aqui en modo protegido
INI_PROTECTED_MODE:
    MOV SI, Hola;Pinta el mensaje en la direcion de memoria
    MOV EBX,0xb8000
    CALL PINTAR
    HLT

;Pinta el mensaje
PINTAR:
    LODSB
    OR AL,AL
    JZ VOLVERpm
    MOV AH,0x0f
    MOV WORD [EBX],AX
    ADD EBX,2
    JMP PINTAR

VOLVERpm:
    RET

times 2048 - ($ - $$) db 0 ;Se rellena el resto con 0            