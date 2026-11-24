# Proyecto-Final-ELDI-2026-2
Instrucciones para ejecutar el código y utilizar el proyecto.
1) Instalar Vivado 2026.1 y Arduino IDE, esto con el objetivo de importar los archivos a la placa Nexys correspondiente, y al microcontrolador ESP32 (para procesar las entradas del control)
2) Una vez hecho esto, se crea un proyecto en cada entorno de desarrollo, importando los archivos src/snake.v y src/constraints.xdc en Vivado, y el archivo src/DualShock_4/DualShock4.ino a la ESP32.
   Tanto la placa Nexys como la ESP32 deben permanecer conectadas a una computadora con puertos USB activos, puesto que ambas se energizan mediante cables micro-USB y USB-C, respectivamente.
4) Se inicia el proceso de síntesis e implementación en Vivado (synthesis -> implementation -> Bitstream -> Programación de la placa), se conectan los 7 puertos GPIO correspondientes de la ESP32 (indicados en la       carpeta src/Dualshock_4) a las entradas PMOD JA de la placa Nexys, utilizando JA1, JA2, JA3, JA4, JA7, JA8, y JA6, este último como un GND común entre ambos dispositivos.
5) Se presiona el botón "EN" en la ESP32, tras lo cual se verifica su funcionamiento en Arduino IDE, mediante Tools -> Serial Monitor -> 115200
6) Se enciende y enlaza el control DualShock 4 presionando los botones "Share" y "PS" al mismo tiempo durante unos segundos, hasta que este muestre un color y comience a intercalarlo rápidamente. Una vez enlazado, la ESP32 mostrará un mensaje indicando esto. Cada entrada que reciba el control se verá en Serial Monitor de Arduino IDE.


