import { initializeApp } from "https://www.gstatic.com/firebasejs/11.9.0/firebase-app.js";
import {
  GoogleAuthProvider,
  getAuth,
  onAuthStateChanged,
  signInWithPopup,
  signOut,
} from "https://www.gstatic.com/firebasejs/11.9.0/firebase-auth.js";
import {
  getFunctions,
  httpsCallable,
} from "https://www.gstatic.com/firebasejs/11.9.0/firebase-functions.js";

const firebaseConfig = {
  apiKey: "AIzaSyDE9_f6zE165N8ixl5l2wzha_apnOPqP5w",
  authDomain: "brounitystudio-d59af.firebaseapp.com",
  databaseURL:
    "https://brounitystudio-d59af-default-rtdb.europe-west1.firebasedatabase.app",
  projectId: "brounitystudio-d59af",
  storageBucket: "brounitystudio-d59af.firebasestorage.app",
  messagingSenderId: "949168519770",
  appId: "1:949168519770:web:82c00e18d10c6a99903663",
  measurementId: "G-XE0RPHCKW8",
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const functions = getFunctions(app, "europe-west1");
const provider = new GoogleAuthProvider();

const $ = (id) => document.getElementById(id);

const loginButton = $("loginButton");
const logoutButton = $("logoutButton");
const statusCard = $("statusCard");
const userEmail = $("userEmail");
const refreshButton = $("refreshButton");
const searchButton = $("searchButton");
const searchInput = $("searchInput");
const usersList = $("usersList");
const premiumButton = $("premiumButton");
const premiumEmail = $("premiumEmail");
const premiumPlan = $("premiumPlan");
const creditsButton = $("creditsButton");
const creditsEmail = $("creditsEmail");
const creditsAmount = $("creditsAmount");
const pushButton = $("pushButton");
const pushEmail = $("pushEmail");
const pushTitle = $("pushTitle");
const pushBody = $("pushBody");
const toast = $("toast");

loginButton.addEventListener("click", () => signInWithPopup(auth, provider));
logoutButton.addEventListener("click", () => signOut(auth));
refreshButton.addEventListener("click", () => loadUsers());
searchButton.addEventListener("click", () => loadUsers(searchInput.value));
searchInput.addEventListener("keydown", (event) => {
  if (event.key === "Enter") loadUsers(searchInput.value);
});

premiumButton.addEventListener("click", async () => {
  const plan = premiumPlan.value;
  await call("adminSetPremiumByEmail", {
    email: premiumEmail.value,
    plan,
    subscriptionActive: plan !== "free",
  });
  showToast("Premium durumu güncellendi.");
  await loadUsers(searchInput.value || premiumEmail.value);
});

creditsButton.addEventListener("click", async () => {
  const credits = Number.parseInt(creditsAmount.value, 10);
  await call("adminSetDiagnosisCreditsByEmail", {
    email: creditsEmail.value,
    credits,
  });
  showToast("Ek teşhis hakkı güncellendi.");
  await loadUsers(searchInput.value || creditsEmail.value);
});

pushButton.addEventListener("click", async () => {
  const result = await call("adminSendPushToEmail", {
    email: pushEmail.value,
    title: pushTitle.value,
    body: pushBody.value,
  });
  showToast(
    `Push gönderildi. Başarılı: ${result.successCount}, hata: ${result.failureCount}`,
  );
});

onAuthStateChanged(auth, async (user) => {
  const signedIn = Boolean(user);
  statusCard.classList.toggle("hidden", !signedIn);
  loginButton.classList.toggle("hidden", signedIn);
  userEmail.textContent = user?.email ?? "-";
  if (signedIn) {
    await loadUsers();
  } else {
    usersList.innerHTML = "";
  }
});

async function loadUsers(query = "") {
  const data = await call("adminListUsers", { query, limit: 50 });
  usersList.innerHTML = "";
  if (!data.users?.length) {
    usersList.innerHTML = `<div class="user"><strong>Kullanıcı bulunamadı</strong></div>`;
    return;
  }
  for (const user of data.users) {
    const item = document.createElement("div");
    item.className = "user";
    item.innerHTML = `
      <strong>${escapeHtml(user.email ?? user.id)}</strong>
      <p class="muted">${escapeHtml(user.displayName ?? user.uid ?? "")}</p>
      <span>${escapeHtml(user.plan ?? "free")}</span>
      <span>${user.subscriptionActive ? "aktif" : "pasif"}</span>
      <span>AI: ${user.premiumUsedThisMonth ?? 0}/${user.premiumMonthlyLimit ?? 0}</span>
      <span>ek hak: ${user.rewardCredits ?? 0}</span>
      <span>bugün kullanılan: ${user.dailyFreeUsed ?? 0}</span>
      <span>bitki: ${user.plantCount ?? 0}</span>
      <span>${user.hasPushToken ? "push var" : "push yok"}</span>
    `;
    item.addEventListener("click", () => {
      premiumEmail.value = user.email ?? "";
      creditsEmail.value = user.email ?? "";
      creditsAmount.value = user.rewardCredits ?? 0;
      pushEmail.value = user.email ?? "";
    });
    usersList.appendChild(item);
  }
}

async function call(name, payload) {
  try {
    const fn = httpsCallable(functions, name);
    const result = await fn(payload);
    return result.data;
  } catch (error) {
    console.error(error);
    showToast(error.message ?? "İşlem tamamlanamadı.");
    throw error;
  }
}

function showToast(message) {
  toast.textContent = message;
  toast.classList.remove("hidden");
  window.clearTimeout(showToast.timer);
  showToast.timer = window.setTimeout(() => {
    toast.classList.add("hidden");
  }, 3200);
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}
