// Every HTML sink is sanitized, including templates with customer/catalog fields.
window.safeHTML = function(value) {
  if(!window.DOMPurify) throw new Error('Sanitizador indisponível. Atualize a página.');
  return window.DOMPurify.sanitize(String(value ?? ''), {FORBID_TAGS:['script','style','iframe','object','embed','form','base','link','meta'],FORBID_ATTR:['srcdoc']});
};
window.escapeHTML = value => String(value ?? '').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
