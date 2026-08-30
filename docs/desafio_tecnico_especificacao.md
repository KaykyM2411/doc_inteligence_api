# Seleção e Recrutamento — Tecnologia: Desenvolvedor
**Lamarck — Sociedade de Advogados**  
*Núcleo de Engenharia de Software*  
*Data de Emissão: 25 de agosto de 2026*  
*Responsável: Kalyl Lamarck Silvério Pereira (Advogado, OAB/RN 12.766)*

---

> ### ⚠️ LEIA ISTO ANTES DE TUDO
> **NÃO PEDIMOS UM SISTEMA FUNCIONANDO. PEDIMOS O PROJETO DE UM SISTEMA E UMA FATIA DELE IMPLEMENTADA.**  
> O que avaliamos é como você recorta o problema, como decide, como especifica antes de escrever código e como conduz o agente de IA que trabalha com você. A seção **“O Tamanho da Entrega”** diz, sem rodeios, o que precisa e o que não precisa estar pronto.

---

## I. Questão

### Um serviço de inteligência documental

Todos os dias o escritório recebe documentos de clientes pelo WhatsApp do atendimento, por e-mail e no balcão: identidades, comprovantes de residência, contracheques, carteiras de trabalho, laudos, procurações, contratos — e fotografias tortas desses mesmos papéis. Hoje uma pessoa abre cada arquivo, descobre o que é, renomeia num padrão interno e digita os dados numa planilha. São quatro minutos por documento, e o volume cresce.

Queremos substituir esse trabalho por um serviço. Chame-o de **DOC Intelligence**.

---

### O produto que queremos construir

A lista abaixo é o **produto-alvo**, e não o escopo da sua entrega: é o alvo que o seu projeto precisa conseguir alcançar.

1. **Receber um documento** — imagem ou PDF — enviado por uma aplicação cliente.
2. **Descobrir que tipo de documento é, extrair os campos que interessam àquele tipo** — de uma identidade, por exemplo: nome, filiação, data de nascimento, número e órgão emissor — e propor um nome padronizado para o arquivo.
3. **Permitir consultar o resultado** de um documento e listar os já processados.
4. **Quando a máquina não tiver confiança no que produziu, não deixar o documento entrar como pronto:** ele fica para conferência humana, e a pessoa conferente corrige o que a máquina errou.
5. **Ser consumido por outros sistemas internos do escritório**, e não por um navegador anônimo na internet aberta.

---

### Fatos do ambiente

Os fatos abaixo são verdadeiros sobre o lugar onde esse serviço vai rodar:

* **a)** A classificação e a extração são feitas por um **modelo de linguagem multimodal de terceiro**. Cada chamada leva entre **5 e 40 segundos**, é cobrada por documento e, de vez em quando, devolve erro ou simplesmente não responde.
* **b)** **Quem envia é o atendimento, do próprio celular**, quase sempre com a foto original da câmera e com o nome que a pessoa deu ao arquivo — `“WhatsApp Image 2026-08-11 at 09.12.33.jpeg”`, `“scan0001.pdf”`. **Não há validação alguma do lado de quem envia.**
* **c)** **O mesmo documento costuma chegar mais de uma vez** — o cliente reenvia por insegurança, o atendimento reenvia por precaução.
* **d)** O conteúdo desses documentos é **dado pessoal, e parte dele é dado pessoal sensível**.
* **e)** A média é de **150 documentos por dia; em dias de pico passa de 800**, concentrados entre 9h e 11h.
* **f)** O modelo do fornecedor **será trocado de versão em algum momento**, e os **prompts vão mudar mais de uma vez** ao longo do primeiro ano.
* **g)** **Duas pessoas do atendimento podem abrir a fila de conferência ao mesmo tempo.**

> 📌 **NENHUM DESSES FATOS PEDE UMA FUNCIONALIDADE — E É POR ISSO QUE ESTÃO AQUI.**  
> Um projeto que os ignore quebra na primeira semana de uso real, e vamos ler o seu procurando saber quais deles você enxergou sozinho. Tratar um fato pode ser resolvê-lo ou apenas registrá-lo como risco conhecido, explicando por que ficou para depois: as duas coisas contam.

---

### Escolha uma trilha

Escolha uma. Não há trilha melhor — escolha a que representa o trabalho que você quer fazer aqui.

* **Trilha A — Back-end:** Projete o serviço: a API, o processamento e a persistência. O consumo por interface gráfica não é seu problema, mas o contrato que você expõe é.
* **Trilha B — Front-end:** Projete a interface do atendimento: enviar vários documentos de uma vez, acompanhar o processamento, trabalhar a fila de conferência com o documento original ao lado dos campos extraídos, corrigir e buscar o que já foi processado. A API ainda não existe — o contrato é seu para definir e servir por mock, e faz parte da entrega.

---

### O tamanho da entrega

* **Você NÃO precisa entregar:** o produto completo, todos os cinco comportamentos, interface polida, deploy, autenticação real ou alta cobertura de testes.
* **Você PRECISA entregar:** o projeto do sistema — arquitetura, decisões e especificação — e uma **fatia vertical implementada**.

> **Fatia vertical** é um caminho completo de ponta a ponta, ainda que estreito.  
> * **Na trilha A:** receber um documento, passá-lo pelo processamento — o modelo de IA pode ser um dublê que devolve sempre a mesma resposta —, gravar e consultar o resultado.  
> * **Na trilha B:** uma tela de verdade sobre dados falsos, do envio até a correção de um campo.  
> 
> *Uma fatia estreita e honesta vale mais do que cinco funcionalidades pela metade, e gastar a maior parte do tempo pensando e escrevendo, em vez de programando, é uma escolha legítima.*

---

## II. Resposta

### O que entregar

1. **Repositório Git**, com link e acesso liberado. Queremos o histórico de commits, e não um único commit chamado “initial”.
2. **O projeto** — a especificação que você escreveu antes de programar e o registro das decisões de arquitetura (ADRs ou documento único, tanto faz): o que decidiu, que alternativas considerou e por que descartou cada uma. Queremos ler sobretudo o que você não fez. Se a implementação divergiu da especificação, entregue a especificação como estava e diga onde divergiu.
3. **A fatia vertical, rodando**, com um README que permita a outra pessoa subir o projeto e um parágrafo dizendo o que você escolheu testar, e por que aquilo.
4. **O registro do uso de IA.** Esperamos que você trabalhe com agentes: é assim que se produz aqui. O uso é livre, o registro é obrigatório:
   * os arquivos de instrução do agente (`CLAUDE.md`, `AGENTS.md` ou equivalente) e as skills, subagentes, comandos, hooks ou servidores MCP que você configurou, tudo versionado no repositório;
   * os prompts, na íntegra e em ordem, num diretório do repositório — como foram escritos, não reescritos depois para ficarem bonitos;
   * um parágrafo sobre onde o agente errou, como você percebeu e o que fez a respeito.  
   *(Se optar por não usar IA, diga com todas as letras e explique o motivo. Também é uma resposta.)*
5. **Carta de fechamento**, de no máximo duas páginas, respondendo a quatro perguntas:
   1. O que ficou de fora e por quê;
   2. O que quebra primeiro se o volume for multiplicado por dez;
   3. Qual das suas decisões você menos defenderia hoje;
   4. Quanto tempo isso tudo levou.

---

### Regras e forma de envio

* **Prazo:** 3 (três) dias corridos a contar do recebimento deste documento.
* **Linguagem, framework, banco, infraestrutura e ferramentas de IA:** escolha sua — e a escolha é conteúdo da avaliação, então justifique-a.
* **Transparência:** O que não foi feito deve estar escrito como não feito, e não escondido. E você pode e deve perguntar: perguntas boas contam a favor, não contra.
* **Privacidade / LGPD:** Nenhum dado real de cliente, de pessoa física ou do escritório. Gere documentos fictícios para testar.
* **Forma de Envio:** A entrega é por e-mail: o link do repositório, com acesso liberado, e a carta de fechamento em PDF. O resto vive dentro do repositório.
* **Formatação da Carta de Fechamento:** Para a carta de fechamento, utilizar a fonte **Roboto**, tamanho **11**, espaçamento entre linhas de **1,15**, espaçamento entre parágrafos de **6 pt** e texto **justificado**. Dentro do repositório, escreva como preferir.

---

### Critérios de Pontuação

| Peso | Critério | Descrição |
| :--- | :--- | :--- |
| **30%** | **Arquitetura e modularidade** | Separação de responsabilidades, fronteiras entre módulos, o que acontece quando uma peça precisa ser trocada. |
| **20%** | **Rastreabilidade das decisões** | A qualidade do raciocínio registrado e a honestidade sobre os trade-offs. |
| **20%** | **Uso de IA como ferramenta de engenharia** | Não “usou ou não usou”, mas com que grau de controle: instrução do agente, estruturação dos prompts, verificação do que voltou. |
| **15%** | **Especificação e método** | Como o trabalho foi recortado antes de começar e como o repositório conta essa história. |
| **15%** | **Atenção e proatividade** | Quanto dos fatos do ambiente você enxergou sozinho e tratou, ou registrou conscientemente como risco. |

---

> *"No fim, o que medimos é o quanto conseguimos entender, lendo o que você entregou, como você pensa — e o quanto gostaríamos de pensar junto. Fique bastante à vontade para tirar dúvidas comigo sobre o escopo, o cenário ou as ferramentas, por e-mail, a qualquer momento do prazo."*  
>  
> **Mossoró, 25 de agosto de 2026.**  
> **Kalyl Lamarck Silvério Pereira**  
> Advogado, OAB/RN 12.766  
> Lamarck — Sociedade de Advogados  
> Rua Melo Franco, 122, Centro, Mossoró/RN. CEP 59600-165
