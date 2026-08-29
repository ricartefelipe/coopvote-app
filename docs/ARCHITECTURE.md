# Arquitetura

## Direção adotada

O aplicativo usa uma arquitetura em camadas pequenas, orientada ao fluxo server-driven. A solução evita um domínio local que apenas repetiria as regras já mantidas pelo backend.

```text
CoopVote API
    |
    | JSON de FORMULARIO ou SELECAO
    v
ScreenApi -> AppScreen/ScreenAction -> ScreenController -> Widgets
                                                      |
                                                      | ação do usuário
                                                      v
                                POST callback + body + valores de entrada
```

## Responsabilidades

### Configuração

`AppConfig` lê `COOPVOTE_ENTRY_URL` em tempo de compilação e fornece a URL inicial. A configuração não depende de arquivos secretos nem de estado global mutável.

### Protocolo

`screen_models.dart` contém os modelos fechados das telas e itens suportados. O parser rejeita respostas incompletas, URLs não absolutas, tipos desconhecidos e identificadores de entrada duplicados.

### Transporte

`ScreenApi` realiza exclusivamente requisições `POST`, codifica corpos JSON, aplica timeout, interpreta respostas UTF-8 e traduz erros HTTP em exceções compreensíveis. O cliente HTTP pode ser injetado nos testes.

### Estado

`ScreenController` mantém a tela corrente, carregamento, erro e última requisição para repetição manual. Uma falha de callback não apaga a última tela válida.

### Apresentação

`ScreenFlowPage` escolhe o widget a partir do tipo recebido. `FormScreenView` administra campos e ações; `SelectionScreenView` apresenta as opções. Nenhum widget conhece endpoints ou regras de votação.

## Razões

- separação suficiente para testar transporte, protocolo e interface isoladamente;
- um único fluxo de navegação comandado pelo servidor;
- dependências reduzidas a HTTP, localização oficial e formatação de data;
- extensão controlada: um novo componente exige um modelo e um renderer explícitos;
- falhas de contrato aparecem cedo, em vez de produzir telas parcialmente incorretas.

Não foram adicionados repositórios, casos de uso, injeção de dependência externa ou gerenciamento de estado de terceiros porque não resolveriam uma necessidade atual do cliente.
