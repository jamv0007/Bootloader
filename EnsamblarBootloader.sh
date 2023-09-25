#!/bin/bash

localizar=$( pwd | ls | grep bootloader.asm )
if [ -z ${localizar} ]
then
	echo "No se encuentra 'bootloader.asm'. Debe ejecutar en el mismo directorio este script"
else
	echo "Ensmblando..."	
	nasm -f bin bootloader.asm -o bootloader.img
	echo "Se ha ensamblado el bootloader"
fi	
