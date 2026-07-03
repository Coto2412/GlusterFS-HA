#!/bin/bash

# Iniciamos el agente SSH y cargamos la llave una sola vez para no pedir la contraseña en cada comando
eval "$(ssh-agent -s)" > /dev/null
ssh-add ~/.ssh/id_rsa

# Extraemos las IPs dinámicamente del inventory.ini generado por Terraform
mapfile -t IPS < <(awk -F'=' '/ansible_host=/ {print $2}' ansible/inventory.ini | awk '{print $1}' | sort -u)

NODE1=${IPS[0]}
NODE2=${IPS[1]}
NODE3=${IPS[2]}

echo "================================================================="
echo "1. Mostrando los tres nodos en funcionamiento (Peer Status)"
echo "================================================================="
ssh -o StrictHostKeyChecking=no jdelpino@$NODE1 "sudo gluster peer status"
echo ""

echo "================================================================="
echo "2. Evidenciando la creación del volumen replicado (Volume Info)"
echo "================================================================="
ssh -o StrictHostKeyChecking=no jdelpino@$NODE1 "sudo gluster volume info gv0"
echo ""

echo "================================================================="
echo "3. Demostrando el montaje del volumen en cada nodo (df -h)"
echo "================================================================="
echo "--- Nodo 1 ($NODE1) ---"
ssh -o StrictHostKeyChecking=no jdelpino@$NODE1 "df -h | grep gluster"
echo "--- Nodo 2 ($NODE2) ---"
ssh -o StrictHostKeyChecking=no jdelpino@$NODE2 "df -h | grep gluster"
echo "--- Nodo 3 ($NODE3) ---"
ssh -o StrictHostKeyChecking=no jdelpino@$NODE3 "df -h | grep gluster"
echo ""

echo "================================================================="
echo "4. Prueba de escritura y lectura entre nodos (Estado Normal)"
echo "================================================================="
echo "-> Escribiendo archivo 'prueba_normal.txt' en el Nodo 1..."
ssh -o StrictHostKeyChecking=no jdelpino@$NODE1 "echo '¡Hola desde el Nodo 1! Este archivo está replicado en los 3 nodos.' | sudo tee /mnt/gluster_vol/prueba_normal.txt"

echo "-> Leyendo el archivo desde el Nodo 2..."
ssh -o StrictHostKeyChecking=no jdelpino@$NODE2 "cat /mnt/gluster_vol/prueba_normal.txt"

echo "-> Leyendo el archivo desde el Nodo 3..."
ssh -o StrictHostKeyChecking=no jdelpino@$NODE3 "cat /mnt/gluster_vol/prueba_normal.txt"
echo ""

echo "================================================================="
echo "5. SIMULACIÓN DE CAÍDA DE NODO (Alta Disponibilidad)"
echo "================================================================="
echo "-> 🔴 Forzando la caída del servicio GlusterFS en el 'nodo-gluster-3'..."
# Solo bloqueamos el tráfico TCP relacionado con Gluster (puertos 24007, 24008 y rango 49152:49251), dejamos el puerto 22 (SSH) libre.
ssh -o StrictHostKeyChecking=no jdelpino@$NODE3 "sudo systemctl stop glusterd && sudo iptables -A INPUT -p tcp --dport 24007:24008 -j DROP && sudo iptables -A INPUT -p tcp --dport 49152:49251 -j DROP"
echo "   [ESPERA] Dando 20 segundos a GlusterFS para detectar la desconexión TCP..."
sleep 20

echo "-> Verificando el estado del clúster desde el Nodo 1..."
echo "   (El nodo 3 debe aparecer como 'Disconnected')"
echo "-------------------------------------------------------"
ssh -o StrictHostKeyChecking=no jdelpino@$NODE1 "sudo gluster peer status | grep -A 2 'node3'"
echo "-------------------------------------------------------"
echo ""

echo "-> ✍️  Escribiendo un NUEVO archivo desde el Nodo 2 mientras el Nodo 3 está MUERTO..."
ssh -o StrictHostKeyChecking=no jdelpino@$NODE2 "echo '¡ALERTA! Este archivo fue escrito mientras el Nodo 3 estaba apagado. HA funcionando perfectamente.' | sudo tee /mnt/gluster_vol/prueba_caida.txt > /dev/null"
echo "   [Comprobación Nodo 2]:"
ssh -o StrictHostKeyChecking=no jdelpino@$NODE2 "ls -l /mnt/gluster_vol/prueba_caida.txt"
echo ""

echo "-> 📖 Leyendo el nuevo archivo desde el Nodo 1 (sigue vivo)..."
echo "   [Contenido leído desde Nodo 1]:"
ssh -o StrictHostKeyChecking=no jdelpino@$NODE1 "cat /mnt/gluster_vol/prueba_caida.txt"
echo ""

echo "================================================================="
echo "6. RECUPERACIÓN DEL NODO Y SELF-HEAL"
echo "================================================================="
echo "-> 🟢 Recuperando la conectividad y el servicio en 'nodo-gluster-3'..."
ssh -o StrictHostKeyChecking=no jdelpino@$NODE3 "sudo iptables -D INPUT -p tcp --dport 24007:24008 -j DROP && sudo iptables -D INPUT -p tcp --dport 49152:49251 -j DROP && sudo systemctl start glusterd"
echo "   [ESPERA] Dando 20 segundos para que GlusterFS reconecte y sincronice los datos perdidos (Self-Heal)..."
sleep 20

echo "-> Verificando que el Nodo 3 ha vuelto al clúster..."
echo "-------------------------------------------------------"
ssh -o StrictHostKeyChecking=no jdelpino@$NODE1 "sudo gluster peer status | grep -A 2 'node3'"
echo "-------------------------------------------------------"
echo ""

echo "-> 📖 Leyendo el archivo creado durante la caída desde el Nodo 3 (recién revivido)..."
echo "   [Comprobación Nodo 3 - ls]:"
ssh -o StrictHostKeyChecking=no jdelpino@$NODE3 "ls -l /mnt/gluster_vol/prueba_caida.txt"
echo "   [Comprobación Nodo 3 - cat]:"
ssh -o StrictHostKeyChecking=no jdelpino@$NODE3 "cat /mnt/gluster_vol/prueba_caida.txt"
echo ""

echo "================================================================="
echo "✅ Pruebas de Alta Disponibilidad finalizadas con éxito."
echo "================================================================="

# Matamos el agente temporal
kill $SSH_AGENT_PID > /dev/null
