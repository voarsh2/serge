<script lang="ts">
  import type { PageData } from "./$types";
  import { invalidate } from "$app/navigation";
  import { page } from "$app/stores";
  import { browser } from "$app/environment";

  export let data: PageData;
  let clear: number;

  $: isLoading = false;
  $: questions = data.props.questions ?? [];
  $: startDate = new Date(data.props.created);

  $: prompt = "";

  $: if (browser) {
    void fetch("/api/chat/" + $page.params.id + "/status")
      .then((r) => r.json())
      .then((data) => {
        if (data === "streaming") {
          void streamPage();
        }
      });
  }

  const streamPage = async () => {
    const requestStream = await fetch(
      "/api/chat/" + $page.params.id + "/stream"
    );

    const dataStream = await requestStream.json();

    if (dataStream.answer === "EOF") {
      await invalidate("/api/chat/" + $page.params.id);
      return;
    } else {
      if (
        questions.length > 0 &&
        questions[questions.length - 1]._id === "STREAM"
      ) {
        questions[questions.length - 1].question = dataStream.question;
        questions[questions.length - 1].answer = dataStream.answer;
      } else {
        questions = [
          ...questions,
          {
            _id: "STREAM",
            question: dataStream.question,
            answer: dataStream.answer,
          },
        ];
      }
    }

    setTimeout(streamPage, 500);
  };

  const askQuestion = async () => {
    if (prompt) {
      const params = new URLSearchParams();
      params.append("prompt", prompt);

      isLoading = true;
      const r = await fetch(
        "/api/chat/" + $page.params.id + "/question?" + params.toString(),
        {
          method: "POST",
        }
      );

      isLoading = false;
      prompt = "";
      await streamPage();
    }
  };

  async function handleKeyDown(event: KeyboardEvent) {
    if (event.key === "Enter" && event.ctrlKey) {
      await askQuestion();
    }
  }

  function createSameSession(sessionID) {
    fetch("/api/chat/" + sessionID)
      .then((response) => response.json())
      .then((data) => {
        const { _id, created, parameters } = data;
        fetch(
          `/api/chat/?model=${parameters.model}&temperature=${parameters.temperature}&top_k=${parameters.top_k}&top_p=${parameters.top_p}&max_length=${parameters.max_length}&context_window=${parameters.context_window}&repeat_last_n=${parameters.repeat_last_n}&repeat_penalty=${parameters.repeat_penalty}&init_prompt=${parameters.init_prompt}&n_threads=${parameters.n_threads}`,
          {
            method: "POST",
            headers: {
              accept: "application/json",
            },
          }
        )
          .then((response) => response.json())
          .then((data) => {
            const newSession = { id: data };
            window.location.href = "/chat/" + newSession.id;
          });
      })
      .catch((error) => console.error(error));
  }

  document.addEventListener("keydown", function (event) {
    if (event.key === "n" && event.altKey) {
      createSameSession($page.params.id);
    }
  });
</script>

<div
  class="max-w-4xl mx-auto h-full max-h-screen relative"
  on:keydown={handleKeyDown}
>
<div class="flex items-center">
  <h1 class="text-4xl font-bold inline-block mr-2">
    Chat with {data.props.parameters.model}
  </h1>
  <button
    type="button"
    disabled={isLoading}
    class="btn btn-sm mr-2 mt-5 mb-5 inline-block"
    class:loading={isLoading}
    on:click|preventDefault={() => createSameSession($page.params.id)}
  >
    New
  </button>
</div>
<h4 class="text-xl font-semibold mb-5">
  Started on {startDate.toLocaleString("en-US")}
</h4>
  <div class="overflow-y-auto h-[calc(97vh-12rem)] px-10 mb-11">
    <div class="h-max pb-32">
      {#each questions as question}
        <div class="chat chat-end my-2">
          <div
            class="chat-bubble chat-bubble-secondary whitespace-pre-line text-lg"
          >
            {question.question}
          </div>
        </div>
        <div class="chat chat-start my-2">
          <div
            class="chat-bubble chat-bubble-primary whitespace-pre-line text-lg"
          >
            {#if question.error}
              A server error occurred. See below:
              <div class="font-mono font-thin text-sm text-gray-100 pt-5">
                {question.error}
              </div>
            {:else}
              {#if question.answer === ""}
                <div
                  class="radial-progress animate-spin"
                  style="--value:70; --size:2rem;"
                />
              {/if}
              {question.answer}
            {/if}
          </div>
        </div>
      {/each}
    </div>
  </div>
  <div
    class="items-center w-full px-0 h-0 flex flex-row bg-base-100 justify-center"
  >
    <textarea
      autofocus
      name="question"
      class="textarea textarea-bordered h-10 w-full max-w-xl mb-5 text-lg"
      disabled={isLoading}
      placeholder="Ask a question..."
      bind:value={prompt}
    />
    <button
      type="submit"
      disabled={isLoading}
      class="btn btn-primary h-10 w-24 text-lg ml-2 mb-5"
      class:loading={isLoading}
      on:click|preventDefault={askQuestion}
    >
      Send
    </button>
  </div>
</div>
