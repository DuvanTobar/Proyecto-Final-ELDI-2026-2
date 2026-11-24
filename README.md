# Snake con Pantalla VGA en FPGA Nexys
Instrucciones para ejecutar el código y utilizar el proyecto.
1) Instalar Vivado 2026.1 y Arduino IDE, esto con el objetivo de importar los archivos a la placa Nexys correspondiente, y al microcontrolador ESP32 (para procesar las entradas del control)
2) Una vez hecho esto, se crea un proyecto en cada entorno de desarrollo, importando los archivos src/snake.v y src/constraints.xdc en Vivado, y el archivo src/DualShock_4/DualShock4.ino a la ESP32.
   Tanto la placa Nexys como la ESP32 deben permanecer conectadas a una computadora con puertos USB activos, puesto que ambas se energizan mediante cables micro-USB y USB-C, respectivamente.
4) Se inicia el proceso de síntesis e implementación en Vivado (synthesis -> implementation -> Bitstream -> Programación de la placa), se conectan los 7 puertos GPIO correspondientes de la ESP32 (indicados en la       carpeta src/Dualshock_4) a las entradas PMOD JA de la placa Nexys, utilizando JA1, JA2, JA3, JA4, JA7, JA8, y JA6, este último como un GND común entre ambos dispositivos.
5) Se presiona el botón "EN" en la ESP32, tras lo cual se verifica su funcionamiento en Arduino IDE, mediante Tools -> Serial Monitor -> 115200
6) Se enciende y enlaza el control DualShock 4 presionando los botones "Share" y "PS" al mismo tiempo durante unos segundos, hasta que este muestre un color y comience a intercalarlo rápidamente. Una vez enlazado, la ESP32 mostrará un mensaje indicando esto. Cada entrada que reciba el control se verá en Serial Monitor de Arduino IDE.


# Declaración de Uso de Inteligencia Artificial

Para la realización de este proyecto, se utilizó la asistencia del modelo de lenguaje Gemini. Este se usó para la creación, diseño, comprensión y corrección de los módulos verilog, archivo de constraints, diseño y comprensión de los esquemáticos, e interpretación del código utilizado por la placa Nexys. Del mismo modo, esta herramienta se utilizó para diseñar el enlace para la recepción de entradas mediante el microcontrolador ESP32, al igual que el código C++ que esta utiliza para recibir las entradas del control DualShock 4 y transmitirlas a la FPGA.

Los dos integrantes del grupo utilizamos esta herramienta mayoritariamente, y fuimos realizando correcciones menores conforme se avanzaba en el desarrollo e implementación del proyecto. El módelo de lenguaje nos ayudó a diseñar y corregir esquemáticos del driver VGA y sus señales correspondientes, renderizado de video y las interfaces adjuntas, las máquinas de estados finitos, LFSR, la memoria del circuito, lógica de entradas, y la arquitectura general al nivel superior de abstracción del Snake.

Asimismo, el módelo de IA se utilizó para realizar numerosas correcciones al código Verilog, puesto que se presentaron diversos errores inesperados a lo largo del desarrollo, los cuales se fueron solucionando progresivamente con la ayuda de la inteligencia artificial. 

No se utilizó ningún modelo de inteligencia artificial para la redacción de este archivo.
