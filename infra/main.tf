terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = var.regiao_aws
}
  #! Aqui as instâncias vão ser criadas automaticamente.

resource "aws_launch_template" "maquina" {   # launch template (uma descrição de uma máquina), que é um template de máquina, um template que vamos criar nossas máquinas com base nele.
  image_id      = "ami-03d5c68bab01f3496"
  instance_type = var.instancia
  key_name = var.chave
  tags = {
    Name = "Terraform Ansible Python"
  }
  security_group_names = [ var.grupoDeSeguranca ]

  # Aqui vamos fazer a máquina se configurar atraves de um script 
  user_data = var.producao ? filebase64("ansible.sh") : ""     # Com esse comando, ele vai é pegar o nosso script e colocar em uma base de 64 caracteres, para que a AWS consiga entender esse script e depois colocar na nossa máquina. 
}                                                              # var.producao já é verdadeira ou falsa, não precisamos compará-la com o verdadeiro ou o falso, ela já é uma booleano, então já podemos utilizar direto. Então vamos carrega-la user_data = var.producao.
                                                               #Agora vem o operador ternário. Vamos colocar um ponto de interrogação e ele vai executar se verdadeiro dois pontos, se falso. Se falso, eu não quero que entre nada no meu user_data
# if(var.producao){
#   filebase64("ansible.sh")
# } else{
#   ""
# }

resource "aws_key_pair" "chaveSSH" {  # Configurando a chave SSH e vinculando a chave com a AWS.
  key_name = var.chave
  public_key = file("${var.chave}.pub") 
}

#! Criando um novo recurso, o autoscaling group. (Com ele podemos começar a configurar a infraestrutura elástica, que é a infraestrutura que cresce e encolhe de acordo com a nossa demanda).

resource "aws_autoscaling_group" "grupo" {
  availability_zones = [ "${var.regiao_aws}a", "${var.regiao_aws}b" ] # Vamos trabalhar com 2 zonas de disponibilidade que são necessárias para o load balancer, porque se acontecer alguma coisa e por algum motivo essa infraestrutura ficar desconectada, continuamos funcionando na outra. 
  name = var.nomeGrupo
  max_size = var.maximo
  min_size = var.minimo
  launch_template {      //  temos que descrever qual vai ser a configuração que vamos usar dentro dele. E como já criamos o nosso launch_template, vamos usá-lo nesse caso, então launch_template, vamos definir o ID como id = aws_launch_template.maquina.id.
    id = aws_launch_template.maquina.id
    version = "$Latest"
  }
  target_group_arns = var.producao ? [ aws_lb_target_group.alvoLoadBalancer[0].arn ] : [] # Aqui é uma configuração que o "autoscaling_group" vai receber as informações do nosso load balancer.
}  # Esse ARNS é um nome que a AWS vai dar para cada recurso que vamos criar. E como vamos ter acesso a esse nome? Podemos fazer da mesma forma que fizemos para pegar o nosso ID, eu vou pegar target_group_arns = aws_lb_target_group. alvoLoadBalancer.arn

# if (var.producao) {
#     [ aws_lb_target_group.alvoLoadBalancer.arn ]
# } else {
#   []
# }

#Aqui vamos criar as subnets, ou as redes internas que são criadas na AWS pelo nosso usuário. E vamos usar a padrão, esse recurso e vinculado às zonas.
resource "aws_default_subnet" "subnet_1" {
  availability_zone = "${var.regiao_aws}a"  // E no corpo dela vamos ter que definir qual é a zona de disponibilidade dela.
}

resource "aws_default_subnet" "subnet_2" {
  availability_zone = "${var.regiao_aws}b"
}

# Aqui vamos criar um LoadBalancer e precisamos colocar só duas características.
resource "aws_lb" "LoadBalancer" {
  internal = false      # Aqui vamos colocar se o loadbalancer é interno, nesse caso é "false" que queremos nos comunicar com a internet, para recebermos as requisições dos nossos clientes. 
  subnets = [ aws_default_subnet.subnet_1.id, aws_default_subnet.subnet_2.id ] # Aqui precisamos setar qual subnet ele vai estar atrelado.
  count = var.producao ? 1 : 0  # Não podemos simplesmente colocar um operador ternário no resource, mas podemos falar quantos recursos desse o Terraform vai criar para nós. Fazemos isso com uma opção chamada count.
}                               # No nosso caso, queremos que seja 1 se a variável de produção for verdadeira ou 0 se a variável de produção for falsa, que é no caso do desenvolvimento.

# Aqui vamos configurar o nosso LoadBalancer para onde ele vai enviar as informações, ou seja, para quais servidores ele vai enviar as informações que chegam nele.
resource "aws_lb_target_group" "alvoLoadBalancer" {
  name = "maquinasAlvo"
  port = "8000"
  protocol = "HTTP"
  vpc_id = aws_default_vpc.default.id # O que é esse vpc_id? Ele é um virtual private cloud, ou uma cloud virtual privada, é onde nossas máquinas ficam na AWS. É um espaço que é nosso.
  count = var.producao ? 1 : 0 
}

# Aqui vamos criar nosso vpv_id como default, ele não tem nenhum tipo de configuração para fazermos, então o bloco dele fica vazio. Eu estou usando o default_vpc, porque é a vpc que a AWS cria para nós.
resource "aws_default_vpc" "default" {
}

# Configuração de entrada do LoadBalancer, o que le vai escutar.
resource "aws_lb_listener" "entradaLoadBalancer" {
  load_balancer_arn = aws_lb.LoadBalancer[0].arn                   # Aqui vamos configurar qual load balancer ele vai pertencer. Para isso vamos usar o load_balancer_arn =. O ARN é um nome único para cada recurso que criamos na AWS.
  port = "8000"
  protocol = "HTTP"
  default_action {                            # Aqui vamos configurar uma ação padrão para ele poder fazer.
    type = "forward"                          # Aqui no type ou o tipo de distribuidor de carga que vamos utilizar. No caso vamos utilizar um tipo que ele vai simplesmente repassar a requisição para as máquinas.
    target_group_arn = aws_lb_target_group. alvoLoadBalancer[0].arn # aqui vamos passar qual vai ser nosso grupo alvo, que no nosso caso vai ser:  aws_lb_target_group.alvoLoadBalancer.arn
  }
  count = var.producao ? 1 : 0 
}

// Criando nosso infraestrutura elástica

resource "aws_autoscaling_policy" "escala-Producao" {
  name = "terraform-escala"
  autoscaling_group_name = var.nomeGrupo  // Definindo o grupo de autoscaling que nesse caso vai ser a variável "var.nomeGrupo" que criamos no resource aws_autoscaling_group.
  policy_type = "TargetTrackingScaling"   // Aqui vamos definir a política de escalagem, Então vamos manter pelo consumo de CPU. O consumo de CPU é o TargetTrackingScaling, é o escalonamento pelo acompanhamento do alvo, digamos assim. Então policy_type = “TargetTrackingScaling”. Então ele vai seguir o uso da nossa CPU para poder definir o que queremos.
  target_tracking_configuration {         //Aqui vamos definir um bloco que vai ser exatamente o que vamos seguir, qual vai ser a métrica utilizada.
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization" // E predefined_metric_type = “ASGAvarageCPUUtilization”, então o tipo de métrica pré-definida que vamos usar. No nosso caso vai ser o ASGAvarageCPUUtilization, que é basicamente o uso médio de CPU que a nossa máquina vai utilizar.
    }
    target_value = 50.0  // Aqui é o valor que queremos de 50% da CPU sendo utilizada. Mais do que isso ele vai criar uma nova máquina para isso, menos do que isso ele pode começar a destruir máquinas até o mínimo, que no caso definimos como uma máquina.
  }
  count = var.producao ? 1 : 0 
}