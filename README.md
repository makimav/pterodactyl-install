# Pterodactyl Install Script
**UNOFFICIAL** script for easy Pterodactyl panel/wings installation.

## Usage:

### Full auto installation
```bash
bash <(curl -s https://raw.githubusercontent.com/makimav/pterodactyl-install/refs/heads/main/pterodactyl-install.sh) full
```
This command will automatically install and configure Pterodactyl panel and wings, no manual configuration required, but you must add eggs you need manually or use default ones.

### Panel installation
```bash
bash <(curl -s https://raw.githubusercontent.com/makimav/pterodactyl-install/refs/heads/main/pterodactyl-install.sh) panel
```
This command will automatically install and configure Pterodactyl panel, you can't create servers until you add a node manually.

To link a node to your panel, go to admin panel and create a location, then create a node, go to "Configuration" tab, then choose either config file or auto-deploy.

#### Using auto-deploy
This method doesn't always work, but it's easier to do.

Just copy and paste command from panel using "Generate Token" button to node's terminal.

Now, do `systemctl restart wings` to restart your node.

#### Using config file
Type `nano /etc/pterodactyl/config.yml` in your node's terminal, then paste the config.

Press Ctrl + X, confirm using Y and then enter to exit the file.

After you have exited, do `systemctl restart wings` to restart your node.

### Node installation
```bash
bash <(curl -s https://raw.githubusercontent.com/makimav/pterodactyl-install/refs/heads/main/pterodactyl-install.sh) node
```
This command will automatically install and configure Pterodactyl wings, you need to connect this node to the panel manually.

## Login details
Once you have installed the panel, you can login using these details:

`admin@admin.com` / `admin`

`admin`

Database password is also `admin`.

Make sure to change these details manually.

Installing ports is very easy ![image](https://github.com/user-attachments/assets/7496b68d-7324-42c5-920e-c3ed3d6eb940)

Installing the egg is also easy, follow the screenshots, you just need to download the json file for your programming language, I will have [nodejs](https://github.com/makimav/pterodactyl-install/blob/main/nodejs.json) for example, and you download the file itself to add it to your panel!
![image](https://github.com/user-attachments/assets/84dde801-1a13-42dd-be20-1501cd5942b2)

![image](https://github.com/user-attachments/assets/05864760-754c-4b74-a020-a0eae68cef88)

![image](https://github.com/user-attachments/assets/39012a60-9330-4a8a-aa94-abaceac4f477)

![image](https://github.com/user-attachments/assets/4383f937-547d-44bf-8274-5de78885925b)
