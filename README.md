# Bootloader

## 1. Descripción del Bootloader
El bootloader implementado es parecido a una consola de comandos. Se ha implementado la primera fase que es el bootloader en si y que carga una second stage donde se ha implementado una especie de terminal parecida a la de linux que permite escribir texto hasta un limite de 128 caracteres como máximo y reconoce una serie de comandos implementados para darle algo de funcionalidad. La captura de teclado se ha realizado usando una ISR. También se ha implementado la GDT y el paso a modo protegido. Ahora se describirá cada elemento implementado de una manera más amplia:
### 1.1 Bootloader
El bootloader implementado permite en primer lugar usando la INT 13h, pasar a modo texto para que no se muestre texto de la carga de floopy en QEMU y tener una pantalla más limpia. Después la única funcionalidad es pasar unicamente a la Second Stage. Por lo que leyendo de disco los sectores que ocupa el programa se salta a la Second Stage donde esta toda la funcionalidad implementada.
### 1.2 Second Stage
Aquí se han implementado varias funcionalidades. La primera y más importante es la sustitución de la IRQ de la IDT ya implementada en el sistema por defecto, por una implementada que permite obtener los scancodes del teclado cuando haya una interrupción por pulsación de tecla y usando XLAT se convierte a texto ASCII con una tabla y se muestra en la pantalla. Dado que se va a implementar que este también reciba comandos, se ha creado un buffer que tiene un tamaño máximo de 128 caracteres por lo que este será el limite que se puede escribir en pantalla.
Para que se parezca más a una consola, se pinta un texto que parece a las consolas de comandos tipo root@system$ que no se puede borrar y los 128 caracteres cuentan a partir de esto.
Se ha implementado también que la tecla de retroceso permita borrar caracteres y con la tecla Enter se permita ejecutar el comando escrito en el momento.

### 1.3. Modo protegido
Se ha implementado el paso a modo protegido usando un comando desde la Second Stage. En el modo protegido lo único que hace es mostrar por pantalla un mensaje que indica que se esta en este modo pero no se puede regresar al modo real. También se ha implementado una GDT que se carga cuando se pasa al modo protegido.
### 1.4. Comandos Implementados
Se han implementado un total de 3 comandos reconocibles en la consola.
• “time”: Permite obtener y pintar la hora actual.
• “clear”: Permite limpiar la pantalla.
• “pm”: Permite pasar a modo protegido y muestra un mensaje como que ha pasado de modo.
## 2. Prueba de funcionamiento
A continuación se mostrará la funcionalidad del bootloader. Para ejecutar el bootloader con QEMU, se usa el siguiente comando:

<img width="877" alt="Captura de pantalla 2023-09-25 a las 14 23 08" src="https://github.com/jamv0007/Bootloader/assets/84525141/1bd867f8-606d-4c8a-9242-9ea69415a27a">

Una vez que lo ejecutemos se mostrará en QEMU lo siguiente:

<img width="874" alt="Captura de pantalla 2023-09-25 a las 14 23 41" src="https://github.com/jamv0007/Bootloader/assets/84525141/119486c8-a33e-4840-8d2d-df5ac49d6ea5">

Se puede usar el teclado para escribir con una limitación de 128 caracteres:

<img width="874" alt="Captura de pantalla 2023-09-25 a las 14 24 11" src="https://github.com/jamv0007/Bootloader/assets/84525141/c89f383f-a80f-4e24-a0bc-0a700989be0b">

Usando el comando “time” se puede mostrar la hora actual:

<img width="875" alt="Captura de pantalla 2023-09-25 a las 14 24 54" src="https://github.com/jamv0007/Bootloader/assets/84525141/592fabec-bd2f-4487-a1a7-23972b1b82d5">

<img width="874" alt="Captura de pantalla 2023-09-25 a las 14 25 13" src="https://github.com/jamv0007/Bootloader/assets/84525141/64f147f1-3656-4b17-b1a6-c594a9845d10">

Con el comando “clear” se limpia la terminal

<img width="866" alt="Captura de pantalla 2023-09-25 a las 14 25 53" src="https://github.com/jamv0007/Bootloader/assets/84525141/be53a73f-ef3a-4bac-89eb-8728e7757277">

<img width="868" alt="Captura de pantalla 2023-09-25 a las 14 26 10" src="https://github.com/jamv0007/Bootloader/assets/84525141/ae858b6e-42a2-4294-bf6a-0009b9222321">

Y con el comando “pm” se pasa a modo protegido:

<img width="867" alt="Captura de pantalla 2023-09-25 a las 14 26 36" src="https://github.com/jamv0007/Bootloader/assets/84525141/a48925d4-7b53-49a4-9a4a-64de7325d635">

## 3. Compilación del bootloader
Ejecutando el script “EnsamblarBootloader.sh”, con el archivo bootloader.asm en el mismo directorio se generará la imagen bootloader.img en el directorio actual. De todas formas si este archivo no esta en el directorio, el script lo indicará con un error.






