'''
import socket

print("Tentative de connexion au Démon Hermes...")

# On crée un socket TCP (notre tuyau)
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

# 127.0.0.1 est l'adresse IP universelle qui veut dire "Mon propre ordinateur" (localhost)
s.connect(('127.0.0.1', 8080))

print("🟢 Connecté ! Envoi d'une commande système factice...")

# On envoie un tableau d'octets brut (le 'b' avant les guillemets fait la conversion)
s.sendall(b"LOCK")

print("Message envoye. Fermeture de la connexion.")
s.close()

'''

import socket
import struct
import time

print("🛠️ Fabrication du paquet Hermes...")

# 1. Nos variables (Les mêmes que dans notre structure Swift)
magic = 0x48524D53
version = 1
type_msg = 1  # 1 correspond à Commande (CommandAction)
payload = b"LOCK"
length = len(payload)
timestamp = int(time.time())
nonce = 123456789

# 2. La Magie de l'Alignement Mémoire !
# "@" : Demande à Python d'utiliser l'alignement mémoire natif du processeur (comme notre Mac)
# I : unsigned int (4 octets)
# H : unsigned short (2 octets)
# Q : unsigned long long (8 octets)
# On respecte l'ordre exact de HermesHeader : magic, version, type, length, timestamp, nonce
header_bytes = struct.pack('@I H H I Q Q', magic, version, type_msg, length, timestamp, nonce)

# 3. Le Paquet final : La Tête + Le Corps
packet = header_bytes + payload

print(f"📏 Taille de l'en-tête mathématique : {len(header_bytes)} octets")
print("🚀 Envoi au serveur...")

# 4. Connexion et Envoi
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
# Envoi du paquet
s.connect(('127.0.0.1', 8080))
s.sendall(packet)

print("⏳ Attente de la réponse binaire du Démon Mac...")
# On lit les 32 premiers octets de la réponse (l'en-tête Hermes)
response_header_bytes = s.recv(32)

if len(response_header_bytes) == 32:
    # On déballe l'en-tête
    magic_res, version_res, type_res, length_res, timestamp_res, nonce_res = struct.unpack('@I H H I Q Q', response_header_bytes)

    print(f"📦 En-tête de réponse reçu ! (Type message: {type_res}, Taille payload attendue: {length_res} octets)")

    # On lit le reste du message (le payload) basé sur la taille indiquée dans l'en-tête
    if length_res > 0:
        response_payload_bytes = s.recv(length_res)
        print(f"✉️ Réponse du Mac décodée : {response_payload_bytes.decode('utf-8')}")
else:
    print("❌ Pas de réponse valide du serveur.")

s.close()
